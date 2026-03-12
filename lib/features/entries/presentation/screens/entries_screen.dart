import 'package:flutter/material.dart';

import '../../../cash_entries/data/models/cash_entry.dart';
import '../../../cash_entries/data/repositories/cash_entry_repository.dart';
import '../../../branches/data/branch_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/glass_widgets.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({
    super.key,
    required this.repository,
    required this.branchRepository,
  });

  final CashEntryRepository repository;
  final BranchRepository branchRepository;

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  DateTimeRange? _dateRange;
  late Future<List<CashEntryRecord>> _futureRecords;
  Map<String, String> _branchNames = const {};

  @override
  void initState() {
    super.initState();
    _futureRecords = _loadRecords();
    _loadBranches();
  }

  Future<List<CashEntryRecord>> _loadRecords() async {
    final records = _dateRange == null
        ? await widget.repository.getAllEntryRecords()
        : await widget.repository.getEntryRecordsByDateRange(
            startDate: _dateRange!.start,
            endDate: _dateRange!.end,
          );
    records.sort((a, b) => b.entry.date.compareTo(a.entry.date));
    return records;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureRecords = _loadRecords();
    });
    await _loadBranches();
    await _futureRecords;
  }

  Future<void> _loadBranches() async {
    _branchNames = await widget.branchRepository.branchNameMap();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Entries',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.filter_alt_rounded),
                tooltip: 'Filter date range',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () async {
                  await _showEntryForm();
                },
                icon: const Icon(Icons.add_circle_rounded),
                color: AppColors.teal,
                tooltip: 'Add entry',
              ),
            ],
          ),
        ),
        if (_dateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtered: ${formatDate(_dateRange!.start)} to ${formatDate(_dateRange!.end)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _futureRecords = _loadRecords();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<CashEntryRecord>>(
            future: _futureRecords,
            builder: (context, snapshot) {
              final records = snapshot.data ?? <CashEntryRecord>[];
              final bottomPadding = screenBottomPadding(context);
              if (records.isEmpty) {
                return const Center(
                  child: GlassCard(
                    child: Text('No entries found. Add your first cash flow entry.'),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding.toDouble()),
                  itemCount: records.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final entry = record.entry;
                    final total = widget.repository.calculateDailyTotal(entry);
                    final branchLabel = _branchNames[entry.branchId] ?? 'Unassigned';

                    return GlassCard(
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatDate(entry.date),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${formatMoney(total)}',
                                  style: TextStyle(
                                    color: total < 0 ? AppColors.danger : AppColors.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Branch: $branchLabel',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _canManage(record.entry)
                                ? () => _showEntryForm(record: record)
                                : null,
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            onPressed: _canManage(record.entry)
                                ? () => _deleteRecord(record.id)
                                : null,
                            icon: const Icon(Icons.delete_rounded),
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateRange = picked;
      _futureRecords = _loadRecords();
    });
  }

  Future<void> _deleteRecord(int id) async {
    await widget.repository.deleteEntryById(id);
    await _refresh();
  }

  Future<void> _showEntryForm({CashEntryRecord? record}) async {
    final result = await showModalBottomSheet<CashEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EntryFormSheet(
        initialEntry: record?.entry,
        branchRepository: widget.branchRepository,
      ),
    );
    if (result == null) {
      return;
    }

    if (record == null) {
      await widget.repository.addEntry(result);
    } else {
      await widget.repository.updateEntry(record.id, result);
    }
    await _refresh();
  }

  bool _canManage(CashEntry entry) => true;
}

class EntryFormSheet extends StatefulWidget {
  const EntryFormSheet({
    super.key,
    this.initialEntry,
    required this.branchRepository,
  });

  final CashEntry? initialEntry;
  final BranchRepository branchRepository;

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _cashController;
  late TextEditingController _cashNotesController;
  late TextEditingController _coinsController;
  late TextEditingController _tillController;
  late TextEditingController _expensesController;
  List<Branch> _branches = const [];
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _date = entry?.date ?? DateTime.now();
    _cashController = TextEditingController(text: entry?.cash.toString() ?? '0');
    _cashNotesController = TextEditingController(text: entry?.cashNotes.toString() ?? '0');
    _coinsController = TextEditingController(text: entry?.coins.toString() ?? '0');
    _tillController = TextEditingController(text: entry?.till.toString() ?? '0');
    _expensesController = TextEditingController(text: entry?.expenses.toString() ?? '0');
    _selectedBranchId = entry?.branchId;
    _loadBranches();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _cashNotesController.dispose();
    _coinsController.dispose();
    _tillController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: GlassCard(
        borderRadius: 24,
        glow: true,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Edit Entry' : 'Add Entry',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Date: ${formatDate(_date)}')),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Change'),
                  ),
                ],
              ),
              _numberField(controller: _cashController, label: 'Cash'),
              _numberField(controller: _cashNotesController, label: 'Cash Notes'),
              _numberField(controller: _coinsController, label: 'Coins'),
              _numberField(controller: _tillController, label: 'Till'),
              _numberField(controller: _expensesController, label: 'Expenses'),
              const SizedBox(height: 8),
              _branchSelector(context),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text('Save Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
        ),
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed == null) {
            return 'Enter a valid number';
          }
          if (parsed < 0) {
            return 'Negative values are not allowed';
          }
          return null;
        },
      ),
    );
  }

  Widget _branchSelector(BuildContext context) {
    if (_branches.isEmpty) {
      return GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(child: Text('Add a business branch to continue.')),
            TextButton(
              onPressed: _addBranch,
              child: const Text('Add branch'),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      decoration: InputDecoration(
        labelText: 'Business branch',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _branches
          .map(
            (branch) => DropdownMenuItem<String>(
              value: branch.id,
              child: Text(branch.name),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Select a business branch';
        }
        return null;
      },
    );
  }

  Future<void> _loadBranches() async {
    _branches = await widget.branchRepository.getAllBranches();
    if (_selectedBranchId == null && _branches.isNotEmpty) {
      _selectedBranchId = _branches.first.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addBranch() async {
    final controller = TextEditingController();
    final branchName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Branch'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Branch name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (branchName == null) {
      return;
    }
    try {
      final branch = await widget.branchRepository.addBranch(branchName);
      await _loadBranches();
      setState(() {
        _selectedBranchId = branch.id;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add branch: $error')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _date = picked;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a business branch before saving.')),
      );
      return;
    }
    final entry = CashEntry(
      date: _date,
      cash: double.parse(_cashController.text),
      cashNotes: double.parse(_cashNotesController.text),
      coins: double.parse(_coinsController.text),
      till: double.parse(_tillController.text),
      expenses: double.parse(_expensesController.text),
      branchId: _selectedBranchId ?? '',
    );
    Navigator.of(context).pop(entry);
  }
}

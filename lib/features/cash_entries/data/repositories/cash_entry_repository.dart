import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/services/access_context.dart';
import '../../../auth/domain/app_role.dart';
import '../models/cash_entry.dart';

class CashEntryRecord {
  const CashEntryRecord({
    required this.id,
    required this.entry,
  });

  final int id;
  final CashEntry entry;
}

class CashEntryRepository {
  static const String boxName = 'cash_entries';

  Future<Box<CashEntry>> openBox() async {
    if (!Hive.isAdapterRegistered(CashEntryAdapter().typeId)) {
      Hive.registerAdapter(CashEntryAdapter());
    }

    if (!Hive.isBoxOpen(boxName)) {
      return Hive.openBox<CashEntry>(boxName);
    }

    return Hive.box<CashEntry>(boxName);
  }

  Future<int> addEntry(CashEntry entry) async {
    final userId = _currentUserIdOrThrow();
    final role = AccessContext.role;
    final resolvedUserId =
        role == AppRole.user ? userId : (entry.userId.isNotEmpty ? entry.userId : userId);
    final resolvedBranchId = AccessContext.branchId ?? entry.branchId;
    if (!_canAssignBranch(resolvedBranchId)) {
      throw StateError('You do not have permission to create entries for this branch.');
    }
    final nextEntry = entry.copyWith(
      userId: resolvedUserId,
      branchId: resolvedBranchId,
    );
    _validateEntry(nextEntry);
    final box = await openBox();
    return box.add(nextEntry);
  }

  Future<List<CashEntry>> getAllEntries() async {
    final box = await openBox();
    return box.values.where(_canReadEntry).toList(growable: false);
  }

  Future<List<CashEntryRecord>> getAllEntryRecords() async {
    final box = await openBox();
    return box.keys
        .map((key) => CashEntryRecord(id: key as int, entry: box.get(key)!))
        .where((record) => _canReadEntry(record.entry))
        .toList(growable: false);
  }

  Future<void> updateEntry(int key, CashEntry entry) async {
    final box = await openBox();
    final existing = box.get(key);
    if (existing != null && !_canManageEntry(existing)) {
      throw StateError('You do not have permission to update this entry.');
    }

    final currentUserId = _currentUserIdOrThrow();
    final role = AccessContext.role;
    final resolvedUserId = role == AppRole.user
        ? currentUserId
        : (existing?.userId.isNotEmpty == true
            ? existing!.userId
            : (entry.userId.isNotEmpty ? entry.userId : currentUserId));
    final resolvedBranchId = existing?.branchId.isNotEmpty == true
        ? existing!.branchId
        : (AccessContext.branchId ?? entry.branchId);
    if (!_canAssignBranch(resolvedBranchId)) {
      throw StateError('You do not have permission to update entries for this branch.');
    }
    final nextEntry = entry.copyWith(
      userId: resolvedUserId,
      branchId: resolvedBranchId,
    );

    _validateEntry(nextEntry);
    await box.put(key, nextEntry);
  }

  Future<void> deleteEntry(int key) async {
    final box = await openBox();
    final existing = box.get(key);
    if (existing != null && !_canManageEntry(existing)) {
      throw StateError('You do not have permission to delete this entry.');
    }
    await box.delete(key);
  }

  Future<void> deleteEntryById(int id) async {
    await deleteEntry(id);
  }

  Future<CashEntry?> getEntry(int key) async {
    final box = await openBox();
    final entry = box.get(key);
    if (entry == null || !_canReadEntry(entry)) {
      return null;
    }
    return entry;
  }

  double calculateDailyTotal(CashEntry entry) {
    _validateEntry(entry);
    return entry.cash + entry.cashNotes + entry.coins + entry.till - entry.expenses;
  }

  Future<List<CashEntry>> getEntriesByDate(DateTime date) async {
    final entries = await getAllEntries();

    return entries.where((entry) {
      return entry.date.year == date.year &&
          entry.date.month == date.month &&
          entry.date.day == date.day;
    }).toList(growable: false);
  }

  Future<List<CashEntryRecord>> getEntryRecordsByDate(DateTime date) async {
    final records = await getAllEntryRecords();
    return records
        .where((record) {
          final entryDate = record.entry.date;
          return entryDate.year == date.year &&
              entryDate.month == date.month &&
              entryDate.day == date.day;
        })
        .toList(growable: false);
  }

  Future<List<CashEntry>> getEntriesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('startDate must be on or before endDate.');
    }

    final entries = await getAllEntries();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    return entries.where((entry) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);

      return !entryDate.isBefore(start) && !entryDate.isAfter(end);
    }).toList(growable: false);
  }

  Future<List<CashEntryRecord>> getEntryRecordsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('startDate must be on or before endDate.');
    }

    final records = await getAllEntryRecords();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    return records
        .where((record) {
          final entry = record.entry;
          final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
          return !entryDate.isBefore(start) && !entryDate.isAfter(end);
        })
        .toList(growable: false);
  }

  void _validateEntry(CashEntry entry) {
    if (entry.cash < 0 ||
        entry.cashNotes < 0 ||
        entry.coins < 0 ||
        entry.till < 0 ||
        entry.expenses < 0) {
      throw ArgumentError('Cash values and expenses must be non-negative.');
    }
  }

  String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

  String _currentUserIdOrThrow() {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('User must be authenticated to manage entries.');
    }
    return userId;
  }

  bool _canReadEntry(CashEntry entry) {
    final role = AccessContext.role;
    final currentUserId = _currentUserId();
    final activeBranchId = AccessContext.branchId;
    final managerBranchIds = _managerBranchIds(activeBranchId);
    if (currentUserId == null) {
      return false;
    }
    switch (role) {
      case AppRole.admin:
        return true;
      case AppRole.manager:
        if (managerBranchIds.isEmpty) {
          return false;
        }
        return managerBranchIds.contains(entry.branchId);
      case AppRole.user:
        return entry.userId == currentUserId;
    }
  }

  bool _canManageEntry(CashEntry entry) => _canReadEntry(entry);

  bool _canAssignBranch(String branchId) {
    switch (AccessContext.role) {
      case AppRole.admin:
        return true;
      case AppRole.manager:
        final managerBranchIds = _managerBranchIds(AccessContext.branchId);
        if (managerBranchIds.isEmpty || branchId.isEmpty) {
          return false;
        }
        return managerBranchIds.contains(branchId);
      case AppRole.user:
        return true;
    }
  }

  Set<String> _managerBranchIds(String? activeBranchId) {
    final ids = <String>{
      for (final id in AccessContext.managedBranchIds)
        if (id.trim().isNotEmpty) id,
    };
    if (activeBranchId != null && activeBranchId.isNotEmpty) {
      ids.add(activeBranchId);
    }
    return ids;
  }
}

Future<void> initializeCashEntryStorage() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(CashEntryAdapter().typeId)) {
    Hive.registerAdapter(CashEntryAdapter());
  }

  if (!Hive.isBoxOpen(CashEntryRepository.boxName)) {
    await Hive.openBox<CashEntry>(CashEntryRepository.boxName);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../cash_entries/data/models/cash_entry.dart';
import '../../../cash_entries/data/repositories/cash_entry_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/glass_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
  });

  final CashEntryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<CashEntry>> _futureEntries;
  final PageController _pageController = PageController(viewportFraction: 0.88);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _futureEntries = _loadEntries();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<List<CashEntry>> _loadEntries() async {
    final entries = await widget.repository.getAllEntries();
    entries.sort((a, b) => b.date.compareTo(a.date));
    _startAutoSlide(entries.length >= 3 ? 3 : entries.length);
    return entries;
  }

  void _startAutoSlide(int count) {
    _timer?.cancel();
    if (count <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        return;
      }
      _currentPage = (_currentPage + 1) % count;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CashEntry>>(
      future: _futureEntries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? <CashEntry>[];
        final latest = entries.isNotEmpty ? entries.first : null;
        final topThree = entries.take(3).toList(growable: false);
        final bottomPadding = screenBottomPadding(context);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _futureEntries = _loadEntries();
            });
            await _futureEntries;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding.toDouble()),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash Flow Tracker',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (topThree.isEmpty)
                const GlassCard(
                  glow: true,
                  child: Text('No entries yet. Add entries in the Entries tab.'),
                )
              else
                _DailyTotalCarousel(
                  entries: topThree,
                  repository: widget.repository,
                  pageController: _pageController,
                  onPageChanged: (value) => _currentPage = value,
                ),
              const SizedBox(height: 16),
              if (latest != null) ...[
                GlassCard(
                  glow: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Most Recent Entry'),
                          const SizedBox(height: 6),
                          Text(
                            formatDate(latest.date),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      Text(
                        formatMoney(widget.repository.calculateDailyTotal(latest)),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width < 640 ? 2 : 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.45,
                  children: [
                    _MetricCard(
                      label: 'Cash',
                      value: latest.cash,
                      icon: Icons.payments_rounded,
                      onTap: () => _showMetricHint('Cash', latest.cash),
                    ),
                    _MetricCard(
                      label: 'Cash Notes',
                      value: latest.cashNotes,
                      icon: Icons.receipt_long_rounded,
                      onTap: () => _showMetricHint('Cash Notes', latest.cashNotes),
                    ),
                    _MetricCard(
                      label: 'Coins',
                      value: latest.coins,
                      icon: Icons.toll_rounded,
                      onTap: () => _showMetricHint('Coins', latest.coins),
                    ),
                    _MetricCard(
                      label: 'Till',
                      value: latest.till,
                      icon: Icons.point_of_sale_rounded,
                      onTap: () => _showMetricHint('Till', latest.till),
                    ),
                    _MetricCard(
                      label: 'Expenses',
                      value: latest.expenses,
                      icon: Icons.money_off_csred_rounded,
                      isDanger: true,
                      onTap: () => _showMetricHint('Expenses', latest.expenses),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showMetricHint(String label, double value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text('$label: ${formatMoney(value)}'),
      ),
    );
  }
}

class _DailyTotalCarousel extends StatelessWidget {
  const _DailyTotalCarousel({
    required this.entries,
    required this.repository,
    required this.pageController,
    required this.onPageChanged,
  });

  final List<CashEntry> entries;
  final CashEntryRepository repository;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final total = repository.calculateDailyTotal(entry);
          final previous = index + 1 < entries.length
              ? repository.calculateDailyTotal(entries[index + 1])
              : null;
          final trend = previous == null ? 0.0 : total - previous;
          final rise = trend >= 0;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GlassCard(
              glow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Total | ${formatDate(entry.date)}'),
                  const Spacer(),
                  Text(
                    formatMoney(total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: rise ? AppColors.teal : AppColors.danger,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        rise ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: rise ? AppColors.teal : AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        previous == null
                            ? 'No previous comparison'
                            : '${trend >= 0 ? '+' : ''}${formatMoney(trend)} vs previous day',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isDanger = false,
    this.onTap,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool isDanger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      glow: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: (isDanger ? AppColors.danger : AppColors.teal).withValues(alpha: 0.16),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isDanger ? AppColors.danger : AppColors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            formatMoney(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDanger ? AppColors.danger : null,
                ),
          ),
        ],
      ),
    );
  }
}

import '../../cash_entries/data/models/cash_entry.dart';
import '../../cash_entries/data/repositories/cash_entry_repository.dart';
import 'analytics_models.dart';

class AnalyticsService {
  AnalyticsService(this._repository);

  final CashEntryRepository _repository;

  Future<AnalyticsSnapshot> buildSnapshot({
    required AnalyticsDateRange range,
    required AnalyticsTrendView trendView,
    Set<String>? branchIds,
  }) async {
    final allEntries = await _repository.getAllEntries();
    final safeEntries = _sanitizeEntries(allEntries);
    final branchFiltered = _filterByBranches(safeEntries, branchIds);
    final filtered = _filterByRange(branchFiltered, range.start, range.end);
    final previousRange = _previousRange(range.start, range.end);
    final previousEntries = _filterByRange(branchFiltered, previousRange.start, previousRange.end);

    final totalRevenue = _revenueTotal(filtered);
    final totalExpenses = _expenseTotal(filtered);
    final netProfit = totalRevenue - totalExpenses;
    final averageDailyRevenue = _averageDailyRevenue(filtered, range.start, range.end);
    final highestDay = _extremeRevenueDay(filtered, highest: true);
    final lowestDay = _extremeRevenueDay(filtered, highest: false);

    final prevRevenue = _revenueTotal(previousEntries);
    final prevExpenses = _expenseTotal(previousEntries);
    final prevNetProfit = prevRevenue - prevExpenses;
    final prevAverageDailyRevenue =
        _averageDailyRevenue(previousEntries, previousRange.start, previousRange.end);
    final prevHighestRevenue =
        _dayRevenueValue(previousEntries, _extremeRevenueDay(previousEntries, highest: true));
    final prevLowestRevenue =
        _dayRevenueValue(previousEntries, _extremeRevenueDay(previousEntries, highest: false));

    final metrics = <AnalyticsMetric>[
      AnalyticsMetric(
        label: 'Total Revenue',
        value: totalRevenue,
        changePercent: _changePercent(totalRevenue, prevRevenue),
      ),
      AnalyticsMetric(
        label: 'Total Expenses',
        value: totalExpenses,
        changePercent: _changePercent(totalExpenses, prevExpenses),
      ),
      AnalyticsMetric(
        label: 'Net Profit',
        value: netProfit,
        changePercent: _changePercent(netProfit, prevNetProfit),
      ),
      AnalyticsMetric(
        label: 'Avg Daily Revenue',
        value: averageDailyRevenue,
        changePercent: _changePercent(averageDailyRevenue, prevAverageDailyRevenue),
      ),
      AnalyticsMetric(
        label: 'Highest Revenue Day',
        value: _dayRevenueValue(filtered, highestDay),
        changePercent: _changePercent(_dayRevenueValue(filtered, highestDay), prevHighestRevenue),
        detail: highestDay == null ? 'N/A' : _labelDate(highestDay),
      ),
      AnalyticsMetric(
        label: 'Lowest Revenue Day',
        value: _dayRevenueValue(filtered, lowestDay),
        changePercent: _changePercent(_dayRevenueValue(filtered, lowestDay), prevLowestRevenue),
        detail: lowestDay == null ? 'N/A' : _labelDate(lowestDay),
      ),
    ];

    return AnalyticsSnapshot(
      filteredEntries: filtered,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      averageDailyRevenue: averageDailyRevenue,
      highestRevenueDay: highestDay,
      lowestRevenueDay: lowestDay,
      metrics: metrics,
      linePoints: _buildTrendPoints(filtered, trendView),
      categoryTotals: _categoryTotals(filtered),
      weekComparison: _buildWeekComparison(branchFiltered),
      monthComparison: _buildMonthComparison(branchFiltered),
    );
  }

  List<CashEntry> _sanitizeEntries(List<CashEntry> entries) {
    return entries.where((entry) {
      return entry.cash >= 0 &&
          entry.cashNotes >= 0 &&
          entry.coins >= 0 &&
          entry.till >= 0 &&
          entry.expenses >= 0;
    }).toList(growable: false);
  }

  List<CashEntry> _filterByRange(List<CashEntry> entries, DateTime start, DateTime end) {
    final s = _dayOnly(start);
    final e = _dayOnly(end);
    return entries.where((entry) {
      final d = _dayOnly(entry.date);
      return !d.isBefore(s) && !d.isAfter(e);
    }).toList(growable: false);
  }

  List<CashEntry> _filterByBranches(List<CashEntry> entries, Set<String>? branchIds) {
    if (branchIds == null || branchIds.isEmpty) {
      return entries;
    }
    return entries.where((entry) => branchIds.contains(entry.branchId)).toList(growable: false);
  }

  ({DateTime start, DateTime end}) _previousRange(DateTime start, DateTime end) {
    final s = _dayOnly(start);
    final e = _dayOnly(end);
    final days = e.difference(s).inDays + 1;
    final prevEnd = s.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    return (start: prevStart, end: prevEnd);
  }

  double _revenue(CashEntry entry) => entry.cash + entry.cashNotes + entry.coins + entry.till;

  double _revenueTotal(List<CashEntry> entries) {
    return entries.fold(0, (sum, e) => sum + _revenue(e));
  }

  double _expenseTotal(List<CashEntry> entries) {
    return entries.fold(0, (sum, e) => sum + e.expenses);
  }

  double _averageDailyRevenue(List<CashEntry> entries, DateTime start, DateTime end) {
    final days = _dayOnly(end).difference(_dayOnly(start)).inDays + 1;
    if (days <= 0) {
      return 0;
    }
    return _revenueTotal(entries) / days;
  }

  DateTime? _extremeRevenueDay(List<CashEntry> entries, {required bool highest}) {
    if (entries.isEmpty) {
      return null;
    }
    final dailyRevenue = <DateTime, double>{};
    for (final entry in entries) {
      final day = _dayOnly(entry.date);
      dailyRevenue[day] = (dailyRevenue[day] ?? 0) + _revenue(entry);
    }
    final sorted = dailyRevenue.entries.toList(growable: false)
      ..sort((a, b) => highest ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    return sorted.first.key;
  }

  double _dayRevenueValue(List<CashEntry> entries, DateTime? day) {
    if (day == null) {
      return 0;
    }
    return entries
        .where((entry) => _dayOnly(entry.date) == day)
        .fold(0, (sum, entry) => sum + _revenue(entry));
  }

  List<AnalyticsSeriesPoint> _buildTrendPoints(List<CashEntry> entries, AnalyticsTrendView view) {
    final grouped = <DateTime, AnalyticsSeriesPoint>{};
    for (final entry in entries) {
      final period = _periodStart(entry.date, view);
      final current = grouped[period];
      final nextRevenue = (current?.revenue ?? 0) + _revenue(entry);
      final nextExpenses = (current?.expenses ?? 0) + entry.expenses;
      grouped[period] = AnalyticsSeriesPoint(
        periodStart: period,
        revenue: nextRevenue,
        expenses: nextExpenses,
      );
    }
    final points = grouped.values.toList(growable: false)
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return points;
  }

  DateTime _periodStart(DateTime date, AnalyticsTrendView view) {
    final d = _dayOnly(date);
    switch (view) {
      case AnalyticsTrendView.daily:
        return d;
      case AnalyticsTrendView.weekly:
        final weekdayOffset = d.weekday - DateTime.monday;
        return d.subtract(Duration(days: weekdayOffset));
      case AnalyticsTrendView.monthly:
        return DateTime(d.year, d.month);
    }
  }

  Map<String, double> _categoryTotals(List<CashEntry> entries) {
    double cash = 0;
    double cashNotes = 0;
    double coins = 0;
    double till = 0;
    double expenses = 0;

    for (final entry in entries) {
      cash += entry.cash;
      cashNotes += entry.cashNotes;
      coins += entry.coins;
      till += entry.till;
      expenses += entry.expenses;
    }

    return {
      'cash': cash,
      'cashNotes': cashNotes,
      'coins': coins,
      'till': till,
      'expenses': expenses,
    };
  }

  AnalyticsComparisonItem _buildWeekComparison(List<CashEntry> entries) {
    final now = _dayOnly(DateTime.now());
    final weekStart = now.subtract(Duration(days: now.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final previousStart = weekStart.subtract(const Duration(days: 7));
    final previousEnd = weekStart.subtract(const Duration(days: 1));
    final current = _revenueTotal(_filterByRange(entries, weekStart, weekEnd));
    final previous = _revenueTotal(_filterByRange(entries, previousStart, previousEnd));
    return AnalyticsComparisonItem(
      label: 'Current week vs previous week',
      currentValue: current,
      previousValue: previous,
      changePercent: _changePercent(current, previous),
    );
  }

  AnalyticsComparisonItem _buildMonthComparison(List<CashEntry> entries) {
    final now = _dayOnly(DateTime.now());
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final current = _revenueTotal(_filterByRange(entries, monthStart, monthEnd));
    final previous = _revenueTotal(_filterByRange(entries, previousMonthStart, previousMonthEnd));
    return AnalyticsComparisonItem(
      label: 'Current month vs previous month',
      currentValue: current,
      previousValue: previous,
      changePercent: _changePercent(current, previous),
    );
  }

  double _changePercent(double current, double previous) {
    if (previous == 0) {
      if (current == 0) {
        return 0;
      }
      return 100;
    }
    return ((current - previous) / previous) * 100;
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _labelDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class AnalyticsDateRange {
  const AnalyticsDateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

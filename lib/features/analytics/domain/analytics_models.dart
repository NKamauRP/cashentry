import '../../cash_entries/data/models/cash_entry.dart';

enum AnalyticsTrendView {
  daily,
  weekly,
  monthly,
}

enum AnalyticsQuickFilter {
  today,
  thisWeek,
  thisMonth,
  custom,
}

class AnalyticsMetric {
  const AnalyticsMetric({
    required this.label,
    required this.value,
    required this.changePercent,
    this.detail,
  });

  final String label;
  final double value;
  final double changePercent;
  final String? detail;
}

class AnalyticsSeriesPoint {
  const AnalyticsSeriesPoint({
    required this.periodStart,
    required this.revenue,
    required this.expenses,
  });

  final DateTime periodStart;
  final double revenue;
  final double expenses;
}

class AnalyticsComparisonItem {
  const AnalyticsComparisonItem({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.changePercent,
  });

  final String label;
  final double currentValue;
  final double previousValue;
  final double changePercent;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.filteredEntries,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.averageDailyRevenue,
    required this.highestRevenueDay,
    required this.lowestRevenueDay,
    required this.metrics,
    required this.linePoints,
    required this.categoryTotals,
    required this.weekComparison,
    required this.monthComparison,
  });

  final List<CashEntry> filteredEntries;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double averageDailyRevenue;
  final DateTime? highestRevenueDay;
  final DateTime? lowestRevenueDay;
  final List<AnalyticsMetric> metrics;
  final List<AnalyticsSeriesPoint> linePoints;
  final Map<String, double> categoryTotals;
  final AnalyticsComparisonItem weekComparison;
  final AnalyticsComparisonItem monthComparison;
}

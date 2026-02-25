import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../../../cash_entries/data/models/cash_entry.dart';
import '../../../cash_entries/data/repositories/cash_entry_repository.dart';
import '../../domain/analytics_models.dart';
import '../../domain/analytics_service.dart';

const Color kGrowthColor = Color(0xFF2ECC71);

class AnalyticsExportScreen extends StatefulWidget {
  const AnalyticsExportScreen({
    super.key,
    required this.repository,
  });

  final CashEntryRepository repository;

  @override
  State<AnalyticsExportScreen> createState() => _AnalyticsExportScreenState();
}

class _AnalyticsExportScreenState extends State<AnalyticsExportScreen> {

  late final AnalyticsService _service;
  AnalyticsQuickFilter _quickFilter = AnalyticsQuickFilter.thisMonth;
  AnalyticsTrendView _trendView = AnalyticsTrendView.daily;
  DateTimeRange _range = _rangeForQuickFilter(AnalyticsQuickFilter.thisMonth);
  late Future<AnalyticsSnapshot> _future;
  final Set<String> _visibleRevenueSegments = {'cash', 'cashNotes', 'coins', 'till'};

  @override
  void initState() {
    super.initState();
    _service = AnalyticsService(widget.repository);
    _future = _loadSnapshot();
  }

  Future<AnalyticsSnapshot> _loadSnapshot() {
    return _service.buildSnapshot(
      range: AnalyticsDateRange(start: _range.start, end: _range.end),
      trendView: _trendView,
    );
  }

  void _reload() {
    setState(() {
      _future = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range_rounded),
                ),
              ],
            ),
            _FilterRow(
              activeFilter: _quickFilter,
              onFilterSelected: (filter) {
                setState(() {
                  _quickFilter = filter;
                  if (filter != AnalyticsQuickFilter.custom) {
                    _range = _rangeForQuickFilter(filter);
                  }
                });
                _reload();
              },
              rangeLabel: '${formatDate(_range.start)} to ${formatDate(_range.end)}',
            ),
            const SizedBox(height: 12),
            if (data == null)
              const Center(child: CircularProgressIndicator())
            else if (data.filteredEntries.isEmpty)
              const _NoDataState()
            else ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: _MetricsGrid(
                  key: ValueKey<String>(
                    '${data.totalRevenue}-${data.totalExpenses}-${_range.start.millisecondsSinceEpoch}-${_range.end.millisecondsSinceEpoch}',
                  ),
                  metrics: data.metrics,
                ),
              ),
              const SizedBox(height: 12),
              _LineChartCard(
                points: data.linePoints,
                trendView: _trendView,
                onTrendViewChanged: (view) {
                  setState(() {
                    _trendView = view;
                  });
                  _reload();
                },
              ),
              const SizedBox(height: 12),
              _BarChartCard(categoryTotals: data.categoryTotals),
              const SizedBox(height: 12),
              _PieChartCard(
                categoryTotals: data.categoryTotals,
                visibleSegments: _visibleRevenueSegments,
                onToggleSegment: (segment) {
                  setState(() {
                    if (_visibleRevenueSegments.contains(segment)) {
                      _visibleRevenueSegments.remove(segment);
                    } else {
                      _visibleRevenueSegments.add(segment);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _ComparisonCard(
                weekComparison: data.weekComparison,
                monthComparison: data.monthComparison,
              ),
              const SizedBox(height: 12),
              _ExportCard(
                onExportCsv: () => _exportCsv(data.filteredEntries),
                onExportPdf: _exportPdfPlaceholder,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _quickFilter = AnalyticsQuickFilter.custom;
      _range = picked;
    });
    _reload();
  }

  Future<void> _exportCsv(List<CashEntry> entries) async {
    final buffer = StringBuffer('date,cash,cashNotes,coins,till,expenses,revenue,netProfit\n');
    for (final entry in entries) {
      final revenue = entry.cash + entry.cashNotes + entry.coins + entry.till;
      final netProfit = revenue - entry.expenses;
      buffer.writeln(
        '${formatDate(entry.date)},${entry.cash},${entry.cashNotes},${entry.coins},${entry.till},${entry.expenses},$revenue,$netProfit',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV exported to clipboard.')),
    );
  }

  Future<void> _exportPdfPlaceholder() async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export placeholder. Implement in next iteration.')),
    );
  }

  static DateTimeRange _rangeForQuickFilter(AnalyticsQuickFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case AnalyticsQuickFilter.today:
        return DateTimeRange(start: today, end: today);
      case AnalyticsQuickFilter.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - DateTime.monday));
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case AnalyticsQuickFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: DateTime(today.year, today.month + 1, 0),
        );
      case AnalyticsQuickFilter.custom:
        return DateTimeRange(start: today, end: today);
    }
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.activeFilter,
    required this.onFilterSelected,
    required this.rangeLabel,
  });

  final AnalyticsQuickFilter activeFilter;
  final ValueChanged<AnalyticsQuickFilter> onFilterSelected;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: true,
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipButton(
                label: 'Today',
                active: activeFilter == AnalyticsQuickFilter.today,
                onTap: () => onFilterSelected(AnalyticsQuickFilter.today),
              ),
              _FilterChipButton(
                label: 'This Week',
                active: activeFilter == AnalyticsQuickFilter.thisWeek,
                onTap: () => onFilterSelected(AnalyticsQuickFilter.thisWeek),
              ),
              _FilterChipButton(
                label: 'This Month',
                active: activeFilter == AnalyticsQuickFilter.thisMonth,
                onTap: () => onFilterSelected(AnalyticsQuickFilter.thisMonth),
              ),
              _FilterChipButton(
                label: 'Custom',
                active: activeFilter == AnalyticsQuickFilter.custom,
                onTap: () => onFilterSelected(AnalyticsQuickFilter.custom),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Range: $rangeLabel'),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.teal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.teal : Theme.of(context).colorScheme.onSurface,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    super.key,
    required this.metrics,
  });

  final List<AnalyticsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.of(context).size.width > 900 ? 3 : 2;
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _MetricCard(metric: metric);
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
  });

  final AnalyticsMetric metric;

  @override
  Widget build(BuildContext context) {
    final positive = metric.changePercent >= 0;
    final trendColor = positive ? kGrowthColor : AppColors.danger;

    return GlassCard(
      glow: true,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            tween: Tween<double>(begin: 0, end: metric.value),
            builder: (context, value, _) {
              return Text(
                formatMoney(value),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              );
            },
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: trendColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${positive ? '+' : ''}${metric.changePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (metric.detail != null)
            Text(
              metric.detail!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.points,
    required this.trendView,
    required this.onTrendViewChanged,
  });

  final List<AnalyticsSeriesPoint> points;
  final AnalyticsTrendView trendView;
  final ValueChanged<AnalyticsTrendView> onTrendViewChanged;

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(
      1,
      (maxValue, point) => max(maxValue, max(point.revenue, point.expenses)),
    );

    return GlassCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trend Over Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _TrendToggle(
                trendView: trendView,
                onChanged: onTrendViewChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.09),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[index].periodStart;
                        final label = trendView == AnalyticsTrendView.monthly
                           ? '${d.month}/${d.year % 100}'
                           : '${d.month}/${d.day}';
                       return Padding(
                         padding: const EdgeInsets.only(top: 6),
                         child: Text(label, style: const TextStyle(fontSize: 10)),
                       );
                     },
                   ),
                 ),
               ),
               lineTouchData: LineTouchData(
                 touchTooltipData: LineTouchTooltipData(
                   getTooltipItems: (items) => items.map((item) {
                     final point = points[item.x.toInt()];
                     final title = '${point.periodStart.year}-${point.periodStart.month.toString().padLeft(2, '0')}-${point.periodStart.day.toString().padLeft(2, '0')}';
                     final kind = item.barIndex == 0 ? 'Revenue' : 'Expenses';
                     return LineTooltipItem(
                       '$title\n$kind: ${item.y.toStringAsFixed(2)}',
                       TextStyle(
                         color: item.barIndex == 0 ? AppColors.teal : AppColors.danger,
                         fontWeight: FontWeight.w700,
                       ),
                     );
                   }).toList(growable: false),
                 ),
               ),
               lineBarsData: [
                 LineChartBarData(
                   isCurved: true,
                   color: AppColors.teal,
                   barWidth: 3,
                   dotData: const FlDotData(show: true),
                   spots: [
                     for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].revenue),
                   ],
                 ),
                 LineChartBarData(
                   isCurved: true,
                   color: AppColors.danger,
                   barWidth: 3,
                   dotData: const FlDotData(show: true),
                   spots: [
                     for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].expenses),
                   ],
                 ),
               ],
             ),
             duration: const Duration(milliseconds: 450),
           ),
         ),
       ],
     ),
   );
 }
}
class _TrendToggle extends StatelessWidget {
 const _TrendToggle({
   required this.trendView,
   required this.onChanged,
 });
 final AnalyticsTrendView trendView;
 final ValueChanged<AnalyticsTrendView> onChanged;
 @override
 Widget build(BuildContext context) {
   return Wrap(
     spacing: 6,
     children: [
       _MiniPill(
         label: 'Daily',
         active: trendView == AnalyticsTrendView.daily,
         onTap: () => onChanged(AnalyticsTrendView.daily),
       ),
       _MiniPill(
         label: 'Weekly',
         active: trendView == AnalyticsTrendView.weekly,
         onTap: () => onChanged(AnalyticsTrendView.weekly),
       ),
       _MiniPill(
         label: 'Monthly',
         active: trendView == AnalyticsTrendView.monthly,
         onTap: () => onChanged(AnalyticsTrendView.monthly),
       ),
     ],
   );
 }
}
class _MiniPill extends StatelessWidget {
 const _MiniPill({
   required this.label,
   required this.active,
   required this.onTap,
 });
 final String label;
 final bool active;
 final VoidCallback onTap;
 @override
 Widget build(BuildContext context) {
   return InkWell(
     onTap: onTap,
     child: AnimatedContainer(
       duration: const Duration(milliseconds: 220),
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(10),
         color: active ? AppColors.teal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
       ),
       child: Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: active ? AppColors.teal : Theme.of(context).colorScheme.onSurface,
           fontWeight: active ? FontWeight.w700 : FontWeight.w500,
         ),
       ),
     ),
   );
 }
}
class _BarChartCard extends StatelessWidget {
 const _BarChartCard({required this.categoryTotals});
 final Map<String, double> categoryTotals;
 static const Map<String, Color> _colors = {
   'cash': Color(0xFF00B8A9),
   'cashNotes': Color(0xFF42A5F5),
   'coins': Color(0xFFAB47BC),
   'till': Color(0xFFFFB74D),
   'expenses': Color(0xFFD94A4A),
 };
 @override
 Widget build(BuildContext context) {
   const order = ['cash', 'cashNotes', 'coins', 'till', 'expenses'];
   final values = order.map((k) => categoryTotals[k] ?? 0).toList(growable: false);
   final maxY = values.fold<double>(1, (m, v) => max(m, v));
   return GlassCard(
     glow: true,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Breakdown by Category',
           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
         ),
         const SizedBox(height: 12),
         SizedBox(
           height: 220,
           child: BarChart(
             BarChartData(
               maxY: maxY * 1.2,
               minY: 0,
               barTouchData: BarTouchData(
                 touchTooltipData: BarTouchTooltipData(
                   getTooltipItem: (group, groupIndex, rod, rodIndex) {
                     final key = order[group.x.toInt()];
                     return BarTooltipItem(
                       '$key\n${rod.toY.toStringAsFixed(2)}',
                       const TextStyle(fontWeight: FontWeight.w700),
                     );
                   },
                 ),
               ),
               gridData: FlGridData(
                 show: true,
                 drawVerticalLine: false,
                 getDrawingHorizontalLine: (value) => FlLine(
                   color: Colors.white.withValues(alpha: 0.09),
                   strokeWidth: 1,
                 ),
               ),
               titlesData: FlTitlesData(
                 topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     getTitlesWidget: (value, meta) {
                       final idx = value.toInt();
                       if (idx < 0 || idx >= order.length) {
                         return const SizedBox.shrink();
                       }
                       return Padding(
                         padding: const EdgeInsets.only(top: 6),
                         child: Text(order[idx], style: const TextStyle(fontSize: 10)),
                       );
                     },
                   ),
                 ),
               ),
               barGroups: [
                 for (int i = 0; i < order.length; i++)
                   BarChartGroupData(
                     x: i,
                     barsSpace: 2,
                     barRods: [
                       BarChartRodData(
                         toY: values[i],
                         width: 18,
                         borderRadius: BorderRadius.circular(8),
                         color: _colors[order[i]],
                       ),
                     ],
                   ),
               ],
             ),
             duration: const Duration(milliseconds: 450),
           ),
         ),
       ],
     ),
   );
 }
}
class _PieChartCard extends StatelessWidget {
 const _PieChartCard({
   required this.categoryTotals,
   required this.visibleSegments,
   required this.onToggleSegment,
 });
 final Map<String, double> categoryTotals;
 final Set<String> visibleSegments;
 final ValueChanged<String> onToggleSegment;
 static const Map<String, Color> _colors = {
   'cash': Color(0xFF00B8A9),
   'cashNotes': Color(0xFF42A5F5),
   'coins': Color(0xFFAB47BC),
   'till': Color(0xFFFFB74D),
 };
 @override
 Widget build(BuildContext context) {
   const order = ['cash', 'cashNotes', 'coins', 'till'];
   final sections = <PieChartSectionData>[];
   for (final key in order) {
     if (!visibleSegments.contains(key)) {
       continue;
     }
     final value = categoryTotals[key] ?? 0;
     if (value <= 0) {
       continue;
     }
     sections.add(
       PieChartSectionData(
         value: value,
         color: _colors[key],
         title: key,
         radius: 74,
         titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
       ),
     );
   }
   return GlassCard(
     glow: true,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Revenue Composition',
           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
         ),
         const SizedBox(height: 10),
         SizedBox(
           height: 220,
           child: PieChart(
             PieChartData(
               sectionsSpace: 2,
               centerSpaceRadius: 42,
               sections: sections,
             ),
             duration: const Duration(milliseconds: 450),
           ),
         ),
         const SizedBox(height: 10),
         Wrap(
           spacing: 8,
           runSpacing: 8,
           children: [
             for (final key in order)
               _LegendToggle(
                 label: key,
                 color: _colors[key]!,
                 active: visibleSegments.contains(key),
                 onTap: () => onToggleSegment(key),
               ),
           ],
         ),
       ],
     ),
   );
 }
}
class _LegendToggle extends StatelessWidget {
 const _LegendToggle({
   required this.label,
   required this.color,
   required this.active,
   required this.onTap,
 });
 final String label;
 final Color color;
 final bool active;
 final VoidCallback onTap;
 @override
 Widget build(BuildContext context) {
   return InkWell(
     onTap: onTap,
     borderRadius: BorderRadius.circular(12),
     child: AnimatedContainer(
       duration: const Duration(milliseconds: 220),
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(12),
         color: active ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
         border: Border.all(color: active ? color : Colors.white.withValues(alpha: 0.22)),
       ),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Container(
             width: 9,
             height: 9,
             decoration: BoxDecoration(
               color: color,
               borderRadius: BorderRadius.circular(99),
             ),
           ),
           const SizedBox(width: 6),
           Text(label),
         ],
       ),
     ),
   );
 }
}
class _ComparisonCard extends StatelessWidget {
 const _ComparisonCard({
   required this.weekComparison,
   required this.monthComparison,
 });
 final AnalyticsComparisonItem weekComparison;
 final AnalyticsComparisonItem monthComparison;
 @override
 Widget build(BuildContext context) {
   return GlassCard(
     glow: true,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Comparison',
           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
         ),
         const SizedBox(height: 10),
         _ComparisonRow(item: weekComparison),
         const SizedBox(height: 8),
         _ComparisonRow(item: monthComparison),
       ],
     ),
   );
 }
}
class _ComparisonRow extends StatelessWidget {
 const _ComparisonRow({required this.item});
 final AnalyticsComparisonItem item;
  @override
  Widget build(BuildContext context) {
    final positive = item.changePercent >= 0;
    final color = positive ? kGrowthColor : AppColors.danger;
   return Row(
     children: [
       Expanded(child: Text(item.label)),
       Text(
         '${positive ? '+' : ''}${item.changePercent.toStringAsFixed(1)}%',
         style: TextStyle(color: color, fontWeight: FontWeight.w700),
       ),
     ],
   );
 }
}
class _ExportCard extends StatelessWidget {
 const _ExportCard({
   required this.onExportCsv,
   required this.onExportPdf,
 });
 final VoidCallback onExportCsv;
 final VoidCallback onExportPdf;
 @override
 Widget build(BuildContext context) {
   return GlassCard(
     glow: true,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Export',
           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
         ),
         const SizedBox(height: 10),
         Wrap(
           spacing: 10,
           children: [
             ElevatedButton.icon(
               onPressed: onExportCsv,
               icon: const Icon(Icons.table_chart_rounded),
               label: const Text('Export CSV'),
             ),
             ElevatedButton.icon(
               onPressed: onExportPdf,
               icon: const Icon(Icons.picture_as_pdf_rounded),
               label: const Text('Export PDF'),
             ),
           ],
         ),
       ],
     ),
   );
 }
}
class _NoDataState extends StatefulWidget {
 const _NoDataState();
 @override
 State<_NoDataState> createState() => _NoDataStateState();
}
class _NoDataStateState extends State<_NoDataState> with SingleTickerProviderStateMixin {
 late final AnimationController _controller;
 @override
 void initState() {
   super.initState();
   _controller = AnimationController(
     vsync: this,
     duration: const Duration(milliseconds: 1200),
     lowerBound: 0.92,
     upperBound: 1.08,
   )..repeat(reverse: true);
 }
 @override
 void dispose() {
   _controller.dispose();
   super.dispose();
 }
 @override
 Widget build(BuildContext context) {
   return GlassCard(
     glow: true,
     child: SizedBox(
       height: 220,
       child: Center(
         child: ScaleTransition(
           scale: _controller,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(
                 Icons.analytics_outlined,
                 size: 52,
                 color: AppColors.teal.withValues(alpha: 0.85),
               ),
               const SizedBox(height: 10),
               Text(
                 'No data available',
                 style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
               ),
               const SizedBox(height: 4),
               Text(
                 'Add entries to unlock analytics insights.',
                 style: Theme.of(context).textTheme.bodySmall,
               ),
             ],
           ),
         ),
       ),
     ),
   );
 }
}



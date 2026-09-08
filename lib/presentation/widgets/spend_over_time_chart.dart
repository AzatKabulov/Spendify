import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../providers/report_providers.dart';

/// Bar chart of expense over the viewed period — daily bars for a week/month,
/// monthly bars for a year. Purely visual; the totals it shows are also in the
/// summary header and breakdown list.
class SpendOverTimeChart extends StatelessWidget {
  const SpendOverTimeChart({required this.bars, super.key});

  final List<SpendBar> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (bars.isEmpty) return const SizedBox.shrink();

    final maxMinor = bars.fold<int>(
      0,
      (m, b) => b.expenseMinor > m ? b.expenseMinor : m,
    );
    // Label every bar for <= 12 bars (yearly / weekly), otherwise every 5th.
    final labelEvery = bars.length <= 12 ? 1 : 5;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxMinor == 0 ? 1 : maxMinor * 1.15,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                formatMinor(rod.toY.round()),
                theme.textTheme.labelSmall ?? const TextStyle(),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  if (i % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      bars[i].label,
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: bars[i].expenseMinor.toDouble(),
                    width: bars.length <= 12 ? 14 : 6,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

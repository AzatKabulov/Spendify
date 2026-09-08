import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/category_colors.dart';
import '../../domain/entities/category.dart';
import '../providers/report_providers.dart';

/// Donut chart of expense by category for the viewed period. It is a visual
/// summary only — the same figures are listed as text in the breakdown list
/// below it (colour is never the sole signal).
class CategoryPie extends StatelessWidget {
  const CategoryPie({
    required this.slices,
    required this.categoriesById,
    super.key,
  });

  final List<CategorySlice> slices;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 48,
          sections: <PieChartSectionData>[
            for (final slice in slices)
              PieChartSectionData(
                value: slice.expenseMinor.toDouble(),
                color: Color(
                  categoriesById[slice.categoryId]?.colorValue ??
                      kFallbackCategoryColor,
                ),
                radius: 44,
                showTitle: slice.fractionOfExpense >= 0.08,
                title: '${(slice.fractionOfExpense * 100).round()}%',
                titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

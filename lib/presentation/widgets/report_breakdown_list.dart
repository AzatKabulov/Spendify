import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../providers/report_providers.dart';
import 'category_avatar.dart';

/// Text version of the pie chart: every category's expense + share, largest
/// first. Carries the same information as the chart for accessibility and
/// colour-blind users (CLAUDE.md Phase 12 rule, applied early).
class ReportBreakdownList extends StatelessWidget {
  const ReportBreakdownList({
    required this.slices,
    required this.categoriesById,
    super.key,
  });

  final List<CategorySlice> slices;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slices.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        for (final slice in slices)
          ListTile(
            dense: true,
            leading: CategoryAvatar(
              category: categoriesById[slice.categoryId],
              radius: 16,
            ),
            title: Text(
              categoriesById[slice.categoryId]?.name ?? 'Uncategorised',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: LinearProgressIndicator(
              value: slice.fractionOfExpense.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatMinor(slice.expenseMinor),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '${(slice.fractionOfExpense * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

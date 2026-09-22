import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/enums.dart';
import '../providers/category_providers.dart';
import '../providers/report_providers.dart';
import '../providers/report_trend_providers.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/reports/report_widgets.dart';
import 'category_breakdown_screen.dart';
import 'trends_screen.dart';

/// Human label for the viewed period — "September 2026", "2026",
/// "8 – 14 Sep · 2026-W37".
String reportPeriodLabel(ReportSelection s) {
  switch (s.type) {
    case PeriodType.monthly:
      return DateFormat('MMMM yyyy').format(s.bounds.start);
    case PeriodType.yearly:
      return s.periodKey;
    case PeriodType.weekly:
      final b = s.bounds;
      final last = b.end.subtract(const Duration(days: 1));
      final fmt = DateFormat('d MMM');
      return '${fmt.format(b.start)} – ${fmt.format(last)}';
    case PeriodType.daily:
      return DateFormat('d MMM yyyy').format(s.bounds.start);
  }
}

/// Opens the period picker: switch weekly/monthly/yearly and step through
/// periods. Replaces the old inline arrows + segmented button.
Future<void> showPeriodPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final selection = ref.watch(reportSelectionProvider);
          final controller = ref.read(reportSelectionProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PillTabs<PeriodType>(
                  values: const <PeriodType>[
                    PeriodType.weekly,
                    PeriodType.monthly,
                    PeriodType.yearly,
                  ],
                  labelOf: (t) => switch (t) {
                    PeriodType.weekly => 'Weekly',
                    PeriodType.monthly => 'Monthly',
                    PeriodType.yearly => 'Yearly',
                    PeriodType.daily => 'Daily',
                  },
                  selected: selection.type,
                  onChanged: controller.setType,
                ),
                const SizedBox(height: Insets.md),
                Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: controller.previous,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous period',
                    ),
                    Expanded(
                      child: Text(
                        reportPeriodLabel(selection),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: controller.canGoNext ? controller.next : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next period',
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: () {
                    controller.jumpToNow();
                    Navigator.of(sheet).pop();
                  },
                  child: const Text('Jump to today'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Weekly / monthly / yearly visual reports, backed entirely by the cached
/// `PeriodAggregate`s (CLAUDE.md §6). A top-level tab, so no back button; the
/// Categories and Trends tabs open the two detail screens.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(reportSelectionProvider);
    final data = ref.watch(reportDataProvider);
    final comparison = ref.watch(periodComparisonProvider);
    final points = ref.watch(trailingPeriodsProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final topCategories = <CategoryTotal>[
      for (final s in data.byCategory.take(5))
        CategoryTotal(
          categoryId: s.categoryId,
          amountMinor: s.expenseMinor,
          fraction: s.fractionOfExpense,
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            Insets.lg,
          ),
          children: <Widget>[
            Text(
              'Reports',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Understand your spending, build a better you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.md),
            PeriodChip(
              label: reportPeriodLabel(selection),
              onTap: () => showPeriodPicker(context, ref),
            ),
            const SizedBox(height: Insets.md),
            PillTabs<int>(
              values: const <int>[0, 1, 2],
              labelOf: (i) => switch (i) {
                0 => 'Overview',
                1 => 'Categories',
                _ => 'Trends',
              },
              selected: 0,
              onChanged: (i) {
                if (i == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoryBreakdownScreen(),
                    ),
                  );
                } else if (i == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TrendsScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: Insets.md),
            if (data.isEmpty)
              _EmptyPeriod(onPickPeriod: () => showPeriodPicker(context, ref))
            else ...<Widget>[
              HomeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Total Spending',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatMinor(data.expenseMinor),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        DeltaPill(
                          change: comparison.expenseChange,
                          goodWhenDown: true,
                        ),
                      ],
                    ),
                    if (comparison.previousExpenseMinor > 0)
                      Text(
                        'vs ${comparison.previousLabel} '
                        '(${formatMinor(comparison.previousExpenseMinor)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: Insets.md),
                    TrendBars(points: points),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md - 2),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: FigureCard(
                        label: 'Total Income',
                        amountMinor: data.incomeMinor,
                        change: comparison.incomeChange,
                      ),
                    ),
                    const SizedBox(width: Insets.sm + 2),
                    Expanded(
                      child: FigureCard(
                        label: 'Net Balance',
                        amountMinor: data.netMinor,
                        change: comparison.netChange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md - 2),
              HomeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Top Categories',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CategoryBreakdownScreen(),
                            ),
                          ),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    if (topCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Insets.sm,
                        ),
                        child: Text(
                          'Only income this period — no expenses to break down.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final row in topCategories)
                        CategoryAmountRow(
                          row: row,
                          category: categoriesById[row.categoryId],
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.onPickPeriod});

  final VoidCallback onPickPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xl, Insets.md, 0),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.insights_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: Insets.md),
          Text(
            'No transactions this period',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Pick another week, month or year to look at.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton(
            onPressed: onPickPeriod,
            child: const Text('Change period'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../providers/report_providers.dart';
import '../providers/report_trend_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/reports/report_widgets.dart';
import 'reports_screen.dart';

/// Which direction of money the breakdown is showing.
enum _Direction { expenses, income, both }

/// Where the money went (or came from) for the viewed period, as a donut
/// plus the same figures in text — colour is never the only signal
/// (CLAUDE.md §6 accessibility).
class CategoryBreakdownScreen extends ConsumerStatefulWidget {
  const CategoryBreakdownScreen({super.key});

  @override
  ConsumerState<CategoryBreakdownScreen> createState() =>
      _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState
    extends ConsumerState<CategoryBreakdownScreen> {
  _Direction _direction = _Direction.expenses;
  bool _showPercentage = false;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(reportSelectionProvider);
    final data = ref.watch(reportDataProvider);
    final incomeRows = ref.watch(incomeByCategoryProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final expenseRows = <CategoryTotal>[
      for (final s in data.byCategory)
        CategoryTotal(
          categoryId: s.categoryId,
          amountMinor: s.expenseMinor,
          fraction: s.fractionOfExpense,
        ),
    ];

    final (rows, totalMinor, caption) = switch (_direction) {
      _Direction.expenses => (expenseRows, data.expenseMinor, 'Total Spending'),
      _Direction.income => (incomeRows, data.incomeMinor, 'Total Income'),
      _Direction.both => (
        _merge(expenseRows, incomeRows),
        data.expenseMinor + data.incomeMinor,
        'Total Activity',
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Category Breakdown',
              subtitle: 'See where your money goes',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  PeriodChip(
                    label: reportPeriodLabel(selection),
                    onTap: () => showPeriodPicker(context, ref),
                  ),
                  const SizedBox(height: Insets.md),
                  PillTabs<_Direction>(
                    values: _Direction.values,
                    labelOf: (d) => switch (d) {
                      _Direction.expenses => 'Expenses',
                      _Direction.income => 'Income',
                      _Direction.both => 'Both',
                    },
                    selected: _direction,
                    onChanged: (d) => setState(() => _direction = d),
                  ),
                  const SizedBox(height: Insets.md),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                      child: Text(
                        'Nothing recorded in this period yet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...<Widget>[
                    HomeCard(
                      child: Column(
                        children: <Widget>[
                          Center(
                            child: BreakdownDonut(
                              rows: rows,
                              categoriesById: categoriesById,
                              totalMinor: totalMinor,
                              caption: caption,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          BreakdownLegend(
                            rows: rows,
                            categoriesById: categoriesById,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md - 2),
                    PillTabs<bool>(
                      values: const <bool>[false, true],
                      labelOf: (p) => p ? 'Percentage' : 'Amount',
                      selected: _showPercentage,
                      onChanged: (p) => setState(() => _showPercentage = p),
                    ),
                    const SizedBox(height: Insets.md - 2),
                    HomeCard(
                      child: Column(
                        children: <Widget>[
                          for (final row in rows)
                            _BreakdownRow(
                              row: row,
                              category: categoriesById[row.categoryId],
                              showPercentage: _showPercentage,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Expense and income per category added together, for the "Both" view.
  List<CategoryTotal> _merge(
    List<CategoryTotal> expenses,
    List<CategoryTotal> income,
  ) {
    final totals = <String, int>{};
    for (final r in expenses) {
      totals[r.categoryId] = (totals[r.categoryId] ?? 0) + r.amountMinor;
    }
    for (final r in income) {
      totals[r.categoryId] = (totals[r.categoryId] ?? 0) + r.amountMinor;
    }
    final grand = totals.values.fold<int>(0, (a, b) => a + b);
    final rows = <CategoryTotal>[
      for (final entry in totals.entries)
        CategoryTotal(
          categoryId: entry.key,
          amountMinor: entry.value,
          fraction: grand == 0 ? 0 : entry.value / grand,
        ),
    ]..sort((x, y) => y.amountMinor.compareTo(x.amountMinor));
    return rows;
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.row,
    required this.category,
    required this.showPercentage,
  });

  final CategoryTotal row;
  final Category? category;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: category == null
                  ? scheme.outline
                  : Color(category!.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.sm + Insets.xs),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorised',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            showPercentage
                ? '${(row.fraction * 100).round()}%'
                : formatMinor(row.amountMinor),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

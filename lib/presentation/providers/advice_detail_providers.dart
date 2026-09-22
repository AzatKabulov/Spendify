import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/enums.dart';
import '../../domain/services/aggregation_service.dart';
import 'report_trend_providers.dart';
import 'repository_providers.dart';
import 'transaction_providers.dart';

/// Real, aggregate-only data for the Insights "detail" screen — the mockup's
/// bespoke "spending decreased" drill-in, generalised to any tapped insight.
///
/// Advice is always generated over the calendar month (`buildAdviceSummary`'s
/// default `PeriodType.monthly`), independent of whatever period the Reports
/// tab happens to be showing — so this reads `periodAggregatesProvider`
/// directly rather than depending on `reportSelectionProvider`.

/// This month's overall expense against last month's, as two [PeriodPoint]s
/// for the same bar-chart widget Reports/Trends already use.
final adviceMonthComparisonProvider = Provider<List<PeriodPoint>>((ref) {
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final now = ref.watch(localTimeProvider)();
  final thisKey = periodKeyFor(now, PeriodType.monthly);
  final lastAnchor = shiftPeriod(PeriodType.monthly, now, -1);
  final lastKey = periodKeyFor(lastAnchor, PeriodType.monthly);

  ({int income, int expense}) totalFor(String key) {
    for (final a in aggregates) {
      if (a.periodType == PeriodType.monthly &&
          a.periodKey == key &&
          a.categoryId == null) {
        return (income: a.totalIncomeMinor, expense: a.totalExpenseMinor);
      }
    }
    return (income: 0, expense: 0);
  }

  final last = totalFor(lastKey);
  final current = totalFor(thisKey);
  return <PeriodPoint>[
    PeriodPoint(
      label: shortPeriodLabel(PeriodType.monthly, lastAnchor),
      expenseMinor: last.expense,
      incomeMinor: last.income,
      isCurrent: false,
    ),
    PeriodPoint(
      label: shortPeriodLabel(PeriodType.monthly, now),
      expenseMinor: current.expense,
      incomeMinor: current.income,
      isCurrent: true,
    ),
  ];
});

/// This-month-vs-last-month change for one category — real RM and percent,
/// never estimated.
class CategoryChange {
  const CategoryChange({
    required this.categoryId,
    required this.currentMinor,
    required this.previousMinor,
  });

  final String categoryId;
  final int currentMinor;
  final int previousMinor;

  int get deltaMinor => currentMinor - previousMinor;
  bool get isDown => deltaMinor < 0;

  /// `null` when there is no previous-month baseline to compare against (a
  /// brand-new category) — shown as "new", never as a fabricated "-100%".
  double? get changeFraction {
    if (previousMinor == 0) return null;
    return deltaMinor / previousMinor;
  }
}

/// Categories with the biggest change in expense this month vs last month,
/// largest absolute change first — the "What changed?" list.
final adviceCategoryChangesProvider = Provider<List<CategoryChange>>((ref) {
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final now = ref.watch(localTimeProvider)();
  final thisKey = periodKeyFor(now, PeriodType.monthly);
  final lastKey = periodKeyFor(
    shiftPeriod(PeriodType.monthly, now, -1),
    PeriodType.monthly,
  );

  final current = <String, int>{};
  final previous = <String, int>{};
  for (final a in aggregates) {
    if (a.periodType != PeriodType.monthly || a.categoryId == null) continue;
    if (a.periodKey == thisKey) current[a.categoryId!] = a.totalExpenseMinor;
    if (a.periodKey == lastKey) previous[a.categoryId!] = a.totalExpenseMinor;
  }

  final ids = <String>{...current.keys, ...previous.keys};
  final changes = <CategoryChange>[
    for (final id in ids)
      CategoryChange(
        categoryId: id,
        currentMinor: current[id] ?? 0,
        previousMinor: previous[id] ?? 0,
      ),
  ]..sort((a, b) => b.deltaMinor.abs().compareTo(a.deltaMinor.abs()));

  return changes.where((c) => c.deltaMinor != 0).toList(growable: false);
});

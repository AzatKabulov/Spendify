import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/services/aggregation_service.dart';
import 'report_providers.dart';
import 'transaction_providers.dart';

/// Everything the redesigned Reports screens need beyond [reportDataProvider]:
/// the previous-period comparison, a trailing run of periods for the charts,
/// income split by category, and the weekday/weekend split.
///
/// All of it reads the cached `PeriodAggregate`s only — never a transaction
/// scan (CLAUDE.md §6).

/// One category's share of a total, for either direction of money.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.amountMinor,
    required this.fraction,
  });

  final String categoryId;
  final int amountMinor;
  final double fraction;
}

/// The viewed period next to the one before it.
class PeriodComparison {
  const PeriodComparison({
    required this.expenseMinor,
    required this.incomeMinor,
    required this.previousExpenseMinor,
    required this.previousIncomeMinor,
    required this.previousLabel,
  });

  final int expenseMinor;
  final int incomeMinor;
  final int previousExpenseMinor;
  final int previousIncomeMinor;

  /// e.g. "August 2026" — what the comparison is against.
  final String previousLabel;

  int get netMinor => incomeMinor - expenseMinor;
  int get previousNetMinor => previousIncomeMinor - previousExpenseMinor;

  /// Percentage change, or `null` when there is no baseline to compare with
  /// (a first period can't be "up 100%").
  double? _change(int now, int before) {
    if (before == 0) return null;
    return (now - before) / before.abs();
  }

  double? get expenseChange => _change(expenseMinor, previousExpenseMinor);
  double? get incomeChange => _change(incomeMinor, previousIncomeMinor);
  double? get netChange => _change(netMinor, previousNetMinor);
}

String _periodLabelFor(PeriodType type, DateTime anchor) {
  switch (type) {
    case PeriodType.monthly:
      return DateFormat('MMMM yyyy').format(anchor);
    case PeriodType.yearly:
      return DateFormat('yyyy').format(anchor);
    case PeriodType.weekly:
      return 'week of ${DateFormat('d MMM').format(anchor)}';
    case PeriodType.daily:
      return DateFormat('d MMM').format(anchor);
  }
}

/// Short axis label for a period — "Sep", "2026", "8 Sep".
String shortPeriodLabel(PeriodType type, DateTime anchor) {
  switch (type) {
    case PeriodType.monthly:
      return DateFormat('MMM').format(anchor);
    case PeriodType.yearly:
      return DateFormat('yyyy').format(anchor);
    case PeriodType.weekly:
    case PeriodType.daily:
      return DateFormat('d MMM').format(anchor);
  }
}

/// Totals for one period in a trailing run.
class PeriodPoint {
  const PeriodPoint({
    required this.label,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.isCurrent,
  });

  final String label;
  final int expenseMinor;
  final int incomeMinor;

  /// `true` for the period the report is currently showing.
  final bool isCurrent;
}

/// Period totals keyed by `periodKey` for the selected [PeriodType].
Map<String, ({int income, int expense})> _totalsByKey(
  Iterable<PeriodAggregate> aggregates,
  PeriodType type,
) {
  final out = <String, ({int income, int expense})>{};
  for (final a in aggregates) {
    if (a.periodType != type || a.categoryId != null) continue;
    out[a.periodKey] = (
      income: a.totalIncomeMinor,
      expense: a.totalExpenseMinor,
    );
  }
  return out;
}

/// The viewed period against the one before it.
final periodComparisonProvider = Provider<PeriodComparison>((ref) {
  final selection = ref.watch(reportSelectionProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final totals = _totalsByKey(aggregates, selection.type);

  final previousAnchor = shiftPeriod(selection.type, selection.anchor, -1);
  final previousKey = periodKeyFor(previousAnchor, selection.type);

  final now = totals[selection.periodKey] ?? (income: 0, expense: 0);
  final before = totals[previousKey] ?? (income: 0, expense: 0);

  return PeriodComparison(
    expenseMinor: now.expense,
    incomeMinor: now.income,
    previousExpenseMinor: before.expense,
    previousIncomeMinor: before.income,
    previousLabel: _periodLabelFor(selection.type, previousAnchor),
  );
});

/// How many periods the trend charts look back over.
const int kTrendPeriodCount = 6;

/// The last [kTrendPeriodCount] periods ending with the viewed one, oldest
/// first — the Reports bar chart and the Trends line chart.
final trailingPeriodsProvider = Provider<List<PeriodPoint>>((ref) {
  final selection = ref.watch(reportSelectionProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final totals = _totalsByKey(aggregates, selection.type);

  final points = <PeriodPoint>[];
  for (var back = kTrendPeriodCount - 1; back >= 0; back--) {
    final anchor = shiftPeriod(selection.type, selection.anchor, -back);
    final key = periodKeyFor(anchor, selection.type);
    final t = totals[key] ?? (income: 0, expense: 0);
    points.add(
      PeriodPoint(
        label: shortPeriodLabel(selection.type, anchor),
        expenseMinor: t.expense,
        incomeMinor: t.income,
        isCurrent: back == 0,
      ),
    );
  }
  return points;
});

/// Income by category for the viewed period, largest first.
final incomeByCategoryProvider = Provider<List<CategoryTotal>>((ref) {
  final selection = ref.watch(reportSelectionProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];

  var total = 0;
  final rows = <CategoryTotal>[];
  for (final a in aggregates) {
    if (a.periodType != selection.type || a.periodKey != selection.periodKey) {
      continue;
    }
    if (a.categoryId == null) continue;
    if (a.totalIncomeMinor <= 0) continue;
    total += a.totalIncomeMinor;
    rows.add(
      CategoryTotal(
        categoryId: a.categoryId!,
        amountMinor: a.totalIncomeMinor,
        fraction: 0,
      ),
    );
  }
  rows.sort((x, y) => y.amountMinor.compareTo(x.amountMinor));
  return <CategoryTotal>[
    for (final r in rows)
      CategoryTotal(
        categoryId: r.categoryId,
        amountMinor: r.amountMinor,
        fraction: total == 0 ? 0 : r.amountMinor / total,
      ),
  ];
});

/// Average daily spend on weekends vs weekdays across the viewed period —
/// the "you spend more at weekends" observation. Computed here from the daily
/// aggregates, so it is a fact about the user's own data, not an AI guess.
class WeekendSplit {
  const WeekendSplit({
    required this.weekdayAverageMinor,
    required this.weekendAverageMinor,
  });

  final int weekdayAverageMinor;
  final int weekendAverageMinor;

  bool get hasBoth => weekdayAverageMinor > 0 && weekendAverageMinor > 0;

  /// How much higher weekend days are, as a fraction (0.4 = 40% more).
  double? get weekendUplift {
    if (!hasBoth) return null;
    return (weekendAverageMinor - weekdayAverageMinor) / weekdayAverageMinor;
  }
}

final weekendSplitProvider = Provider<WeekendSplit>((ref) {
  final selection = ref.watch(reportSelectionProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final bounds = selection.bounds;

  var weekdayTotal = 0;
  var weekdayDays = 0;
  var weekendTotal = 0;
  var weekendDays = 0;

  for (final a in aggregates) {
    if (a.periodType != PeriodType.daily || a.categoryId != null) continue;
    final day = DateTime.tryParse(a.periodKey);
    if (day == null) continue;
    if (day.isBefore(bounds.start) || !day.isBefore(bounds.end)) continue;

    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    if (isWeekend) {
      weekendTotal += a.totalExpenseMinor;
      weekendDays++;
    } else {
      weekdayTotal += a.totalExpenseMinor;
      weekdayDays++;
    }
  }

  return WeekendSplit(
    weekdayAverageMinor: weekdayDays == 0 ? 0 : weekdayTotal ~/ weekdayDays,
    weekendAverageMinor: weekendDays == 0 ? 0 : weekendTotal ~/ weekendDays,
  );
});

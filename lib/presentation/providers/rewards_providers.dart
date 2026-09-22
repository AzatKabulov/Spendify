import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/services/aggregation_service.dart';
import 'repository_providers.dart';
import 'transaction_providers.dart';

/// View data for the Rewards screens that isn't already on
/// `GamificationState`: which days the user actually logged something, and
/// the per-period activity counts.
///
/// Every figure comes from the cached daily `PeriodAggregate`s — the same
/// source the reports use, so nothing here scans the transaction table
/// (CLAUDE.md §6).

/// One day in the streak strip / heatmap.
class ActivityDay {
  const ActivityDay({
    required this.date,
    required this.transactionCount,
    required this.isFuture,
  });

  final DateTime date;
  final int transactionCount;

  /// Days after today — drawn as empty placeholders, never as "missed".
  final bool isFuture;

  bool get hasActivity => transactionCount > 0;
}

/// Daily transaction counts keyed by `yyyy-MM-dd`.
Map<String, int> _dailyCounts(Iterable<PeriodAggregate> aggregates) {
  final out = <String, int>{};
  for (final a in aggregates) {
    if (a.periodType != PeriodType.daily || a.categoryId != null) continue;
    out[a.periodKey] = a.transactionCount;
  }
  return out;
}

/// The seven days of the current week (Monday first) — the streak strip.
final currentWeekActivityProvider = Provider<List<ActivityDay>>((ref) {
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final counts = _dailyCounts(aggregates);
  final now = ref.watch(localTimeProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return <ActivityDay>[
    for (var i = 0; i < 7; i++)
      () {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        return ActivityDay(
          date: day,
          transactionCount: counts[periodKeyFor(day, PeriodType.daily)] ?? 0,
          isFuture: day.isAfter(today),
        );
      }(),
  ];
});

/// How many weeks of history the activity heatmap shows.
const int kHeatmapWeeks = 9;

/// [kHeatmapWeeks] weeks ending with the current one, oldest first, each a
/// Monday-first run of seven days — the activity heatmap.
final activityHeatmapProvider = Provider<List<List<ActivityDay>>>((ref) {
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final counts = _dailyCounts(aggregates);
  final now = ref.watch(localTimeProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));

  return <List<ActivityDay>>[
    for (var w = kHeatmapWeeks - 1; w >= 0; w--)
      <ActivityDay>[
        for (var d = 0; d < 7; d++)
          () {
            final day = DateTime(
              thisMonday.year,
              thisMonday.month,
              thisMonday.day - w * 7 + d,
            );
            return ActivityDay(
              date: day,
              transactionCount:
                  counts[periodKeyFor(day, PeriodType.daily)] ?? 0,
              isFuture: day.isAfter(today),
            );
          }(),
      ],
  ];
});

/// The window the "Your Stats" screen is showing.
enum StatsRange { thisMonth, last3Months, thisYear, allTime }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
    StatsRange.thisMonth => 'This Month',
    StatsRange.last3Months => 'Last 3 Months',
    StatsRange.thisYear => 'This Year',
    StatsRange.allTime => 'All Time',
  };

  /// What the previous-window comparison is called, or `null` for All Time
  /// (there is nothing before it to compare against).
  String? get comparisonLabel => switch (this) {
    StatsRange.thisMonth => 'vs last month',
    StatsRange.last3Months => 'vs previous 3 months',
    StatsRange.thisYear => 'vs last year',
    StatsRange.allTime => null,
  };
}

class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.thisMonth;

  void set(StatsRange range) => state = range;
}

final statsRangeProvider = NotifierProvider<StatsRangeNotifier, StatsRange>(
  StatsRangeNotifier.new,
);

/// Activity totals for the selected [StatsRange] and the window before it.
class RangeActivity {
  const RangeActivity({
    required this.transactionCount,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.previousTransactionCount,
    required this.activeDays,
  });

  final int transactionCount;
  final int expenseMinor;
  final int incomeMinor;
  final int previousTransactionCount;

  /// Days in the window with at least one transaction.
  final int activeDays;

  /// Change in transaction count against the previous window, or `null` when
  /// there is no baseline (All Time, or an empty previous window).
  double? get transactionChange {
    if (previousTransactionCount == 0) return null;
    return (transactionCount - previousTransactionCount) /
        previousTransactionCount;
  }
}

/// Inclusive-start / exclusive-end bounds for a range, plus the window
/// immediately before it. `null` start means "everything".
({DateTime? start, DateTime end, DateTime? prevStart, DateTime? prevEnd})
_rangeBounds(StatsRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  switch (range) {
    case StatsRange.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      final prevStart = DateTime(now.year, now.month - 1, 1);
      return (
        start: start,
        end: tomorrow,
        prevStart: prevStart,
        prevEnd: start,
      );
    case StatsRange.last3Months:
      final start = DateTime(now.year, now.month - 2, 1);
      final prevStart = DateTime(now.year, now.month - 5, 1);
      return (
        start: start,
        end: tomorrow,
        prevStart: prevStart,
        prevEnd: start,
      );
    case StatsRange.thisYear:
      final start = DateTime(now.year, 1, 1);
      final prevStart = DateTime(now.year - 1, 1, 1);
      return (
        start: start,
        end: tomorrow,
        prevStart: prevStart,
        prevEnd: start,
      );
    case StatsRange.allTime:
      return (start: null, end: tomorrow, prevStart: null, prevEnd: null);
  }
}

final rangeActivityProvider = Provider<RangeActivity>((ref) {
  final range = ref.watch(statsRangeProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final now = ref.watch(localTimeProvider)();
  final b = _rangeBounds(range, now);

  var count = 0;
  var expense = 0;
  var income = 0;
  var activeDays = 0;
  var previousCount = 0;

  for (final a in aggregates) {
    if (a.periodType != PeriodType.daily || a.categoryId != null) continue;
    final day = DateTime.tryParse(a.periodKey);
    if (day == null) continue;

    final inWindow =
        !day.isAfter(b.end) &&
        day.isBefore(b.end) &&
        (b.start == null || !day.isBefore(b.start!));
    if (inWindow) {
      count += a.transactionCount;
      expense += a.totalExpenseMinor;
      income += a.totalIncomeMinor;
      if (a.transactionCount > 0) activeDays++;
      continue;
    }

    final prevStart = b.prevStart;
    final prevEnd = b.prevEnd;
    if (prevStart != null &&
        prevEnd != null &&
        !day.isBefore(prevStart) &&
        day.isBefore(prevEnd)) {
      previousCount += a.transactionCount;
    }
  }

  return RangeActivity(
    transactionCount: count,
    expenseMinor: expense,
    incomeMinor: income,
    previousTransactionCount: previousCount,
    activeDays: activeDays,
  );
});

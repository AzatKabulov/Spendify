/// Pure period-aggregation logic. No Hive, no Flutter, no repository access,
/// **no `DateTime.now()`** — every caller passes the time in.
///
/// Consistency with Phase 3's `BudgetEvaluator`: weeks start on **Monday** and
/// months/years are calendar-aligned. Weekly period keys use ISO-8601 week
/// numbering, whose *boundaries* are identical to Phase 3's Monday-start weeks —
/// only the label (`2026-W36`) differs.
library;

import '../entities/enums.dart';
import '../entities/period_aggregate.dart';
import '../entities/transaction.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// ISO-8601 week number and week-numbering year for [date] (Monday-start).
///
/// The week-numbering year can differ from the calendar year at the edges:
/// 29 Dec 2025 is `2026-W01`; 1 Jan 2027 is `2026-W53`.
({int weekYear, int week}) isoWeekOf(DateTime date) {
  // Work in UTC date-only to keep the day arithmetic exact.
  final d = DateTime.utc(date.year, date.month, date.day);
  // Thursday of the current ISO week decides which year the week belongs to.
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstDayOfWeekYear = DateTime.utc(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(firstDayOfWeekYear).inDays; // 0-based
  return (weekYear: thursday.year, week: 1 + dayOfYear ~/ 7);
}

/// The Monday (UTC date-only) that starts ISO week [week] of [weekYear].
DateTime mondayOfIsoWeek(int weekYear, int week) {
  final jan4 = DateTime.utc(weekYear, 1, 4); // always in ISO week 1
  final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
  return week1Monday.add(Duration(days: (week - 1) * 7));
}

/// Canonical `periodKey` for [date] at [type]:
/// monthly `2026-09`, weekly `2026-W36`, yearly `2026`.
String periodKeyFor(DateTime date, PeriodType type) {
  switch (type) {
    case PeriodType.monthly:
      return '${date.year}-${_two(date.month)}';
    case PeriodType.yearly:
      return '${date.year}';
    case PeriodType.weekly:
      final iso = isoWeekOf(date);
      return '${iso.weekYear}-W${_two(iso.week)}';
  }
}

/// `[start, end)` local date-only window for a `(type, periodKey)`. Used for
/// report navigation bounds and for bucketing the "spend over time" chart.
({DateTime start, DateTime end}) periodBounds(
  PeriodType type,
  String periodKey,
) {
  switch (type) {
    case PeriodType.monthly:
      final parts = periodKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return (
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 1),
      );
    case PeriodType.yearly:
      final year = int.parse(periodKey);
      return (start: DateTime(year, 1, 1), end: DateTime(year + 1, 1, 1));
    case PeriodType.weekly:
      final parts = periodKey.split('-W');
      final weekYear = int.parse(parts[0]);
      final week = int.parse(parts[1]);
      final monday = mondayOfIsoWeek(weekYear, week);
      final start = DateTime(monday.year, monday.month, monday.day);
      return (
        start: start,
        end: DateTime(start.year, start.month, start.day + 7),
      );
  }
}

/// Move [anchor] by [steps] periods of [type] (negative = earlier). Returns a
/// date that lands inside the target period.
DateTime shiftPeriod(PeriodType type, DateTime anchor, int steps) {
  switch (type) {
    case PeriodType.monthly:
      return DateTime(anchor.year, anchor.month + steps, 1);
    case PeriodType.yearly:
      return DateTime(anchor.year + steps, 1, 1);
    case PeriodType.weekly:
      final d = DateTime(anchor.year, anchor.month, anchor.day);
      return DateTime(d.year, d.month, d.day + 7 * steps);
  }
}

/// The six aggregate ids a transaction contributes to:
/// {weekly, monthly, yearly} × {its category, the period total}.
List<String> aggregateIdsFor(Transaction t, String userId) {
  final ids = <String>[];
  for (final type in PeriodType.values) {
    final key = periodKeyFor(t.date, type);
    ids.add(
      PeriodAggregate.buildId(
        userId: userId,
        periodType: type,
        periodKey: key,
        categoryId: t.categoryId,
      ),
    );
    ids.add(
      PeriodAggregate.buildId(userId: userId, periodType: type, periodKey: key),
    );
  }
  return ids;
}

/// Full recomputation of every aggregate from [transactions]. The source of
/// truth for correctness; [rebuildAllAggregates] on the maintenance repo calls
/// this, and the "50 random ops" test compares incremental results against it.
///
/// Rules (must match `BudgetEvaluator`): exclude `isDeleted`; bucket by
/// `transaction.date`; keep income and expense separate; count every
/// non-deleted transaction; emit both a per-category and a period-total
/// aggregate for every `(periodType, periodKey)` that has any activity.
List<PeriodAggregate> computeAggregates({
  required Iterable<Transaction> transactions,
  required String userId,
  required DateTime now,
}) {
  final acc = <String, _Bucket>{};

  void bump(String id, _Key key, Transaction t) {
    final b = acc.putIfAbsent(id, () => _Bucket(key));
    if (t.type == TransactionType.income) {
      b.income += t.amountMinor;
    } else {
      b.expense += t.amountMinor;
    }
    b.count += 1;
  }

  for (final t in transactions) {
    if (t.isDeleted) continue;
    for (final type in PeriodType.values) {
      final periodKey = periodKeyFor(t.date, type);
      final catKey = _Key(type, periodKey, t.categoryId);
      final totalKey = _Key(type, periodKey, null);
      bump(_idOf(catKey, userId), catKey, t);
      bump(_idOf(totalKey, userId), totalKey, t);
    }
  }

  return [
    for (final entry in acc.entries)
      PeriodAggregate(
        id: entry.key,
        userId: userId,
        periodType: entry.value.key.type,
        periodKey: entry.value.key.periodKey,
        categoryId: entry.value.key.categoryId,
        totalIncomeMinor: entry.value.income,
        totalExpenseMinor: entry.value.expense,
        transactionCount: entry.value.count,
        updatedAt: now,
      ),
  ];
}

String _idOf(_Key k, String userId) => PeriodAggregate.buildId(
  userId: userId,
  periodType: k.type,
  periodKey: k.periodKey,
  categoryId: k.categoryId,
);

class _Key {
  const _Key(this.type, this.periodKey, this.categoryId);
  final PeriodType type;
  final String periodKey;
  final String? categoryId;
}

class _Bucket {
  _Bucket(this.key);
  final _Key key;
  int income = 0;
  int expense = 0;
  int count = 0;
}

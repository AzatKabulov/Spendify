import '../entities/budget.dart';
import '../entities/enums.dart';
import '../entities/transaction.dart';

/// Warning thresholds — the single source of truth.
///
///   fraction >= 0.80            -> approaching
///   fraction  > 1.00            -> exceeded
///   fraction == 1.00 exactly    -> approaching (NOT exceeded)
///
/// "exceeded" is a strict `>` so a budget spent to exactly its limit is still
/// only "approaching" — you have not yet gone over.
const double kBudgetApproachingThreshold = 0.80;
const double kBudgetExceededThreshold = 1.00;

enum BudgetLevel { safe, approaching, exceeded }

/// Structured result of evaluating one [Budget] over a period. Plain data, no
/// display strings and no UI concerns — the Gamification Engine (Phase 8) reads
/// the same object to award XP for staying within a limit.
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spentMinor,
    required this.limitMinor,
    required this.remainingMinor,
    required this.fractionUsed,
    required this.level,
    required this.periodStart,
    required this.periodEnd,
  });

  /// The budget this status is for (plain domain data; kept so callers don't
  /// have to carry the budget alongside separately).
  final Budget budget;

  /// Total expense in sen counted against the budget this period (>= 0).
  final int spentMinor;

  /// The budget's limit in sen (> 0 for a well-formed budget).
  final int limitMinor;

  /// `limitMinor - spentMinor`. **Negative when over budget.**
  final int remainingMinor;

  /// `spentMinor / limitMinor` (0.0 if the limit is non-positive).
  final double fractionUsed;

  final BudgetLevel level;

  /// The window actually evaluated: `[periodStart, periodEnd)`, local date-only.
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get isApproaching => level == BudgetLevel.approaching;
  bool get isExceeded => level == BudgetLevel.exceeded;
  bool get needsAttention => level != BudgetLevel.safe;

  @override
  String toString() =>
      'BudgetStatus(${budget.id}, ${level.name}, $spentMinor/$limitMinor, '
      '${periodStart.toIso8601String()}..${periodEnd.toIso8601String()})';
}

/// Evaluates [budget] against [transactions] as of [now].
///
/// **[now] is injected, never `DateTime.now()`** — the period-boundary tests
/// depend on being able to pin it.
///
/// Rules (must match the Phase 4 aggregation service):
///  1. Only [TransactionType.expense] counts. Income is ignored entirely.
///  2. Soft-deleted transactions are excluded.
///  3. A transaction counts if its `date` (not `createdAt`) falls in
///     `[periodStart, periodEnd)`, compared date-only.
///  4. Category budget (`categoryId != null`): only that category's expenses.
///     Overall budget (`categoryId == null`): every category's expenses.
///  5. Overall and category budgets are evaluated independently — the same
///     transaction can count toward both.
///
/// Periods are **calendar-aligned** and use **local device time**:
///  - monthly: the calendar month containing [now] — day 1 00:00 to the first
///    instant of the next month.
///  - weekly: the Monday–Sunday week containing [now] — `[Monday 00:00,
///    Monday + 7 days)`. Monday start matches Malaysian convention and is the
///    same week-start used by the Phase 4 reports.
///
/// [Budget.startDate] is **not** used here: periods are calendar-aligned, not
/// rolling from the budget's creation date. The field is retained on the entity
/// for a possible future rolling-period option.
BudgetStatus evaluateBudget({
  required Budget budget,
  required List<Transaction> transactions,
  required DateTime now,
}) {
  final (periodStart, periodEnd) = budgetPeriodWindow(budget.period, now);
  final startDay = _dateOnly(periodStart);
  final endDay = _dateOnly(periodEnd);

  var spent = 0;
  for (final t in transactions) {
    if (t.isDeleted) continue;
    if (t.type != TransactionType.expense) continue;
    if (budget.categoryId != null && t.categoryId != budget.categoryId) {
      continue;
    }
    final d = _dateOnly(t.date);
    if (d.isBefore(startDay)) continue;
    if (!d.isBefore(endDay)) continue; // d >= periodEnd -> next period
    spent += t.amountMinor;
  }

  final limit = budget.limitAmountMinor;
  final fraction = limit <= 0 ? 0.0 : spent / limit;

  return BudgetStatus(
    budget: budget,
    spentMinor: spent,
    limitMinor: limit,
    remainingMinor: limit - spent,
    fractionUsed: fraction,
    level: budgetLevelFor(fraction),
    periodStart: periodStart,
    periodEnd: periodEnd,
  );
}

/// Builds a [BudgetStatus] from an already-known [spentMinor] — the Phase 4
/// path, where `spentMinor` comes from a cached `PeriodAggregate` rather than a
/// transaction scan. Period window + level logic is shared with [evaluateBudget]
/// so the two stay consistent.
BudgetStatus budgetStatusFromSpent({
  required Budget budget,
  required int spentMinor,
  required DateTime now,
}) {
  final (periodStart, periodEnd) = budgetPeriodWindow(budget.period, now);
  final limit = budget.limitAmountMinor;
  final fraction = limit <= 0 ? 0.0 : spentMinor / limit;
  return BudgetStatus(
    budget: budget,
    spentMinor: spentMinor,
    limitMinor: limit,
    remainingMinor: limit - spentMinor,
    fractionUsed: fraction,
    level: budgetLevelFor(fraction),
    periodStart: periodStart,
    periodEnd: periodEnd,
  );
}

BudgetLevel budgetLevelFor(double fractionUsed) {
  if (fractionUsed > kBudgetExceededThreshold) return BudgetLevel.exceeded;
  if (fractionUsed >= kBudgetApproachingThreshold) {
    return BudgetLevel.approaching;
  }
  return BudgetLevel.safe;
}

/// `[start, end)` for the calendar period containing [now]. Local, date-only
/// (00:00). Exposed for reuse by the Phase 4 reports.
(DateTime, DateTime) budgetPeriodWindow(BudgetPeriod period, DateTime now) {
  switch (period) {
    case BudgetPeriod.monthly:
      final start = DateTime(now.year, now.month, 1);
      // DateTime normalises month 13 -> January next year.
      final end = DateTime(now.year, now.month + 1, 1);
      return (start, end);
    case BudgetPeriod.weekly:
      final today = DateTime(now.year, now.month, now.day);
      // Monday == weekday 1 ... Sunday == 7. Calendar-day arithmetic (no
      // Duration) so it is DST-agnostic.
      final start = DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1),
      );
      final end = DateTime(start.year, start.month, start.day + 7);
      return (start, end);
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

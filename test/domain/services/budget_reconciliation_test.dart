import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/services/aggregation_service.dart';
import 'package:spendify/domain/services/budget_evaluator.dart';

/// Trust-but-verify for the two budget-evaluation paths that coexist by design:
///
///  - `evaluateBudget(...)`      — the Phase 3 reference; scans transactions.
///  - `budgetStatusFromSpent(...)` — the Phase 4 UI path; takes `spentMinor`
///    from a cached `PeriodAggregate`.
///
/// For any randomized input, feeding `budgetStatusFromSpent` the expense total
/// that `computeAggregates` rolls up for the budget's `(period, category)` must
/// yield the **same** `BudgetStatus` the reference produces. If a
/// period-boundary rule ever drifts between `budgetPeriodWindow` (used by the
/// reference) and `periodKeyFor` (used by the aggregates), a case here fails
/// instead of two screens silently disagreeing.
void main() {
  const userId = 'u';
  const categories = ['food', 'transport', 'bills', 'fun', 'health'];

  PeriodType periodTypeFor(BudgetPeriod p) =>
      p == BudgetPeriod.weekly ? PeriodType.weekly : PeriodType.monthly;

  /// The exact lookup `budgetStatusesProvider` does in production.
  int spentFromAggregates(
    List<PeriodAggregate> aggregates,
    Budget budget,
    DateTime now,
  ) {
    final type = periodTypeFor(budget.period);
    final id = PeriodAggregate.buildId(
      userId: userId,
      periodType: type,
      periodKey: periodKeyFor(now, type),
      categoryId: budget.categoryId,
    );
    for (final a in aggregates) {
      if (a.id == id) return a.totalExpenseMinor;
    }
    return 0;
  }

  test('evaluateBudget == budgetStatusFromSpent over 300 randomized cases', () {
    final rng = Random(4102026);
    var checked = 0;

    for (var caseNo = 0; caseNo < 300; caseNo++) {
      // --- random "now" ------------------------------------------------------
      final now = DateTime(
        2025 + rng.nextInt(3),
        1 + rng.nextInt(12),
        1 + rng.nextInt(28),
      );

      // --- random transactions, dates spanning several periods around now ---
      final txns = <Transaction>[];
      final txnCount = rng.nextInt(30);
      for (var i = 0; i < txnCount; i++) {
        final offsetDays = rng.nextInt(181) - 90; // -90..+90
        final date = DateTime(now.year, now.month, now.day + offsetDays);
        txns.add(
          Transaction(
            id: 'c${caseNo}_t$i',
            userId: userId,
            amountMinor: 1 + rng.nextInt(100000),
            type: rng.nextInt(5) == 0
                ? TransactionType.income
                : TransactionType.expense,
            categoryId: categories[rng.nextInt(categories.length)],
            date: date,
            source: TransactionSource.manual,
            createdAt: date,
            updatedAt: date,
            isDeleted: rng.nextInt(7) == 0, // ~1 in 7 soft-deleted
          ),
        );
      }

      // --- random budget ---------------------------------------------------
      final budget = Budget(
        id: 'c${caseNo}_b',
        userId: userId,
        categoryId: rng.nextInt(3) == 0
            ? null // overall
            : categories[rng.nextInt(categories.length)],
        limitAmountMinor: 1 + rng.nextInt(200000),
        period: rng.nextBool() ? BudgetPeriod.weekly : BudgetPeriod.monthly,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // --- reference vs aggregate-backed ---------------------------------
      final reference = evaluateBudget(
        budget: budget,
        transactions: txns,
        now: now,
      );

      final aggregates = computeAggregates(
        transactions: txns,
        userId: userId,
        now: now,
      );
      final fromAgg = budgetStatusFromSpent(
        budget: budget,
        spentMinor: spentFromAggregates(aggregates, budget, now),
        now: now,
      );

      final ctx =
          'case $caseNo (now=$now, period=${budget.period.name}, '
          'cat=${budget.categoryId ?? "ALL"}, txns=$txnCount)';
      expect(fromAgg.spentMinor, reference.spentMinor, reason: 'spent — $ctx');
      expect(fromAgg.level, reference.level, reason: 'level — $ctx');
      expect(
        fromAgg.remainingMinor,
        reference.remainingMinor,
        reason: 'remaining — $ctx',
      );
      expect(
        fromAgg.fractionUsed,
        reference.fractionUsed,
        reason: 'fraction — $ctx',
      );
      checked++;
    }

    expect(checked, 300);
  });

  test('a case with spend straddling the period boundary still agrees', () {
    // Explicit regression pin: a weekly budget evaluated on a Monday, with
    // expenses on the Sunday before (previous week) and the Monday itself.
    final monday = DateTime(2026, 9, 14); // ISO W38 starts here
    final budget = Budget(
      id: 'b',
      userId: userId,
      categoryId: 'food',
      limitAmountMinor: 10000,
      period: BudgetPeriod.weekly,
      startDate: monday,
      createdAt: monday,
      updatedAt: monday,
    );
    final txns = <Transaction>[
      Transaction(
        id: 'sun',
        userId: userId,
        amountMinor: 9000,
        type: TransactionType.expense,
        categoryId: 'food',
        date: DateTime(2026, 9, 13), // previous week
        source: TransactionSource.manual,
        createdAt: monday,
        updatedAt: monday,
      ),
      Transaction(
        id: 'mon',
        userId: userId,
        amountMinor: 3000,
        type: TransactionType.expense,
        categoryId: 'food',
        date: monday,
        source: TransactionSource.manual,
        createdAt: monday,
        updatedAt: monday,
      ),
    ];

    final reference = evaluateBudget(
      budget: budget,
      transactions: txns,
      now: monday,
    );
    final aggregates = computeAggregates(
      transactions: txns,
      userId: userId,
      now: monday,
    );
    final fromAgg = budgetStatusFromSpent(
      budget: budget,
      spentMinor: aggregates
          .firstWhere(
            (a) =>
                a.periodType == PeriodType.weekly &&
                a.periodKey == '2026-W38' &&
                a.categoryId == 'food',
          )
          .totalExpenseMinor,
      now: monday,
    );

    expect(reference.spentMinor, 3000); // only the Monday expense
    expect(fromAgg.spentMinor, reference.spentMinor);
    expect(fromAgg.level, reference.level);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/domain/services/gamification_rules.dart';
import 'package:spendify/presentation/providers/gamification_providers.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  group('lastCompletedBudgetPeriod (pure)', () {
    Budget monthly({DateTime? startDate}) => Budget.create(
      id: 'b1',
      userId: 'u',
      limitAmountMinor: 50000,
      period: BudgetPeriod.monthly,
      startDate: startDate ?? DateTime(2020, 1, 1),
      now: startDate ?? DateTime(2020, 1, 1),
    );

    test('monthly -> previous calendar month key', () {
      final period = lastCompletedBudgetPeriod(
        monthly(),
        DateTime(2026, 9, 15),
      );
      expect(period?.type, PeriodType.monthly);
      expect(period?.key, '2026-08');
    });

    test('weekly -> previous ISO week key', () {
      final b = Budget.create(
        id: 'b1',
        userId: 'u',
        limitAmountMinor: 10000,
        period: BudgetPeriod.weekly,
        startDate: DateTime(2020, 1, 1),
        now: DateTime(2020, 1, 1),
      );
      // 2026-09-15 is a Tuesday in ISO week 38; previous completed week is W37.
      final period = lastCompletedBudgetPeriod(b, DateTime(2026, 9, 15));
      expect(period?.type, PeriodType.weekly);
      expect(period?.key, '2026-W37');
    });

    test(
      'null when the budget did not exist for the whole previous period',
      () {
        // created 10 Aug — did not cover all of August
        final period = lastCompletedBudgetPeriod(
          monthly(startDate: DateTime(2026, 8, 10)),
          DateTime(2026, 9, 15),
        );
        expect(period, isNull);
      },
    );

    test('not null when created exactly on the previous period start', () {
      final period = lastCompletedBudgetPeriod(
        monthly(startDate: DateTime(2026, 8, 1)),
        DateTime(2026, 9, 15),
      );
      expect(period?.key, '2026-08');
    });
  });

  group('reconciler (wired)', () {
    // pumpSpendify pins "now" to 2026-09-15, so the previous month is 2026-08.
    Budget augustBudget() => Budget.create(
      id: 'b1',
      userId: kLocalUserId,
      limitAmountMinor: 50000, // RM 500
      period: BudgetPeriod.monthly,
      startDate: DateTime(2026, 7, 1),
      now: DateTime.utc(2026, 7, 1),
    );

    PeriodAggregate augustSpend(int expenseMinor) => PeriodAggregate(
      id: PeriodAggregate.buildId(
        userId: kLocalUserId,
        periodType: PeriodType.monthly,
        periodKey: '2026-08',
      ),
      userId: kLocalUserId,
      periodType: PeriodType.monthly,
      periodKey: '2026-08',
      totalIncomeMinor: 0,
      totalExpenseMinor: expenseMinor,
      transactionCount: 3,
      updatedAt: DateTime.utc(2026, 8, 31),
    );

    testWidgets('within-limit period awards the big XP', (tester) async {
      final repos = await pumpSpendify(tester, home: const _Blank());
      await repos.budgets.add(augustBudget());
      await repos.aggregates.put(augustSpend(30000)); // RM 300 <= RM 500

      await repos.container
          .read(gamificationReconcilerProvider)
          .runIfSignedIn();
      await tester.pumpAndSettle();

      final state = await repos.gamification.get();
      expect(state?.xp, kXpBudgetPeriodWithinLimit);
      expect(state?.budgetPeriodsWithinLimit, 1);
      expect(state?.unlockedBadgeIds, contains('budget_kept'));
    });

    testWidgets('exceeded period awards nothing and never penalises', (
      tester,
    ) async {
      final repos = await pumpSpendify(tester, home: const _Blank());
      await repos.budgets.add(augustBudget());
      await repos.aggregates.put(augustSpend(80000)); // RM 800 > RM 500

      await repos.container
          .read(gamificationReconcilerProvider)
          .runIfSignedIn();
      await tester.pumpAndSettle();

      final state = await repos.gamification.get();
      expect(state?.xp ?? 0, 0);
      expect(state?.budgetPeriodsWithinLimit ?? 0, 0);
    });

    testWidgets('running twice awards once', (tester) async {
      final repos = await pumpSpendify(tester, home: const _Blank());
      await repos.budgets.add(augustBudget());
      await repos.aggregates.put(augustSpend(10000));

      final reconciler = repos.container.read(gamificationReconcilerProvider);
      await reconciler.runIfSignedIn();
      await tester.pumpAndSettle();
      await reconciler.runIfSignedIn();
      await tester.pumpAndSettle();

      final state = await repos.gamification.get();
      expect(state?.budgetPeriodsWithinLimit, 1);
      expect(state?.xp, kXpBudgetPeriodWithinLimit);
    });
  });
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

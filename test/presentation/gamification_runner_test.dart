import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/domain/services/gamification_engine.dart';
import 'package:spendly/domain/services/gamification_rules.dart';
import 'package:spendly/presentation/providers/gamification_providers.dart';

import '../support/fake_repositories.dart';

/// The runner is the seam between the fire-and-forget action layer and the pure
/// engine: read state → run engine → persist → surface feedback, serialised.
void main() {
  late FakeGamificationStateRepository stateRepo;
  late FakeCategoryRepository categoryRepo;
  late FakePeriodAggregateRepository aggregateRepo;
  late List<GamificationResult> feedback;

  GamificationRunner buildRunner() => GamificationRunner(
    stateRepo: stateRepo,
    engine: const GamificationEngine(),
    categories: categoryRepo,
    aggregates: aggregateRepo,
    localNow: () => DateTime(2026, 9, 9, 10),
    onFeedback: feedback.add,
  );

  Transaction txn(
    String id, {
    TransactionSource source = TransactionSource.manual,
  }) => Transaction.create(
    id: id,
    userId: 'u',
    amountMinor: 1500,
    type: TransactionType.expense,
    categoryId: 'cat-0',
    date: DateTime(2026, 9, 9),
    now: DateTime.utc(2026, 9, 9),
    source: source,
  );

  setUp(() {
    stateRepo = FakeGamificationStateRepository(
      userId: 'u',
      clock: () => DateTime.utc(2026, 9, 9),
    );
    categoryRepo = FakeCategoryRepository();
    aggregateRepo = FakePeriodAggregateRepository();
    feedback = <GamificationResult>[];
  });

  test(
    'a logged transaction persists XP + coins and surfaces feedback',
    () async {
      final runner = buildRunner();

      runner.transactionLogged(txn('t1'));
      await runner.whenIdle;

      final state = await stateRepo.get();
      expect(state, isNotNull);
      expect(state!.xp, kXpPerTransactionLogged + kXpDailyFirstLog);
      expect(state.transactionsLogged, 1);
      expect(feedback, hasLength(1));
      expect(
        feedback.single.xpAwarded,
        kXpPerTransactionLogged + kXpDailyFirstLog,
      );
    },
  );

  test('delete reverses the per-log XP and does not toast', () async {
    final runner = buildRunner();

    runner.transactionLogged(txn('t1'));
    await runner.whenIdle;
    final afterLog = (await stateRepo.get())!.xp;

    runner.transactionDeleted(txn('t1'));
    await runner.whenIdle;

    final afterDelete = (await stateRepo.get())!.xp;
    expect(afterDelete, afterLog - kXpPerTransactionLogged);
    // one feedback entry only — from the log, not the delete
    expect(feedback, hasLength(1));
  });

  test('the same transaction logged twice awards once (idempotent)', () async {
    final runner = buildRunner();

    runner.transactionLogged(txn('t1'));
    runner.transactionLogged(txn('t1'));
    await runner.whenIdle;

    final state = await stateRepo.get();
    expect(state!.transactionsLogged, 1);
    expect(state.xp, kXpPerTransactionLogged + kXpDailyFirstLog);
  });

  test('delete then undo nets the XP back', () async {
    final runner = buildRunner();

    runner.transactionLogged(txn('t1'));
    await runner.whenIdle;
    final afterLog = (await stateRepo.get())!.xp;

    runner.transactionDeleted(txn('t1'));
    await runner.whenIdle;
    runner.transactionLogged(txn('t1')); // undo re-adds the row
    await runner.whenIdle;

    expect((await stateRepo.get())!.xp, afterLog);
  });

  test('budget created unlocks first_budget', () async {
    final runner = buildRunner();

    runner.budgetCreated(
      Budget.create(
        id: 'b1',
        userId: 'u',
        limitAmountMinor: 50000,
        period: BudgetPeriod.monthly,
        startDate: DateTime.utc(2026, 9, 1),
        now: DateTime.utc(2026, 9, 1),
      ),
    );
    await runner.whenIdle;

    final state = await stateRepo.get();
    expect(state!.unlockedBadgeIds, contains('first_budget'));
    expect(feedback.single.newlyUnlockedBadgeIds, contains('first_budget'));
  });

  test(
    'all_categories resolves from cached per-category yearly aggregates',
    () async {
      await categoryRepo.ensureDefaultsSeeded();
      final categories = await categoryRepo.getAll();
      // Every category has a yearly aggregate with a positive count.
      for (final c in categories) {
        await aggregateRepo.put(
          PeriodAggregate(
            id: PeriodAggregate.buildId(
              userId: 'u',
              periodType: PeriodType.yearly,
              periodKey: '2026',
              categoryId: c.id,
            ),
            userId: 'u',
            periodType: PeriodType.yearly,
            periodKey: '2026',
            categoryId: c.id,
            totalIncomeMinor: 0,
            totalExpenseMinor: 100,
            transactionCount: 1,
            updatedAt: DateTime.utc(2026, 9, 9),
          ),
        );
      }
      final runner = buildRunner();

      runner.transactionLogged(txn('t1'));
      await runner.whenIdle;

      expect(
        (await stateRepo.get())!.unlockedBadgeIds,
        contains('all_categories'),
      );
    },
  );

  test('budgetPeriodCompleted within limit is the big award', () async {
    final runner = buildRunner();

    runner.budgetPeriodCompleted(
      budgetId: 'b1',
      periodKey: '2026-08',
      period: BudgetPeriod.monthly,
      stayedWithinLimit: true,
    );
    await runner.whenIdle;

    final state = await stateRepo.get();
    expect(state!.xp, kXpBudgetPeriodWithinLimit);
    expect(state.budgetPeriodsWithinLimit, 1);
  });
}

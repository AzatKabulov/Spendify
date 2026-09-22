// Verifies the Phase 12 demo dataset seeds a coherent state: a realistic
// history, the aggregate cache rebuilt from it, three budgets (one safe, one
// approaching, one exceeded this month), and a gamification state.
//
// The seeder is gated on `--dart-define=DEMO_SEED=true`, so run this file with
// that flag:
//
//   flutter test --dart-define=DEMO_SEED=true test/dev/demo_seed_test.dart
//
// Without the flag the single test is skipped (the full `flutter test` run
// stays green and fast).

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/core/dev/demo_seed.dart';
import 'package:spendify/data/repositories/hive_budget_repository.dart';
import 'package:spendify/data/repositories/hive_gamification_state_repository.dart';
import 'package:spendify/data/repositories/hive_period_aggregate_repository.dart';
import 'package:spendify/data/repositories/hive_transaction_repository.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/services/budget_evaluator.dart';

import '../support/hive_test_harness.dart';

const _enabled = bool.fromEnvironment('DEMO_SEED');

void main() {
  late HiveTestHarness harness;

  setUp(() async {
    harness = await HiveTestHarness.start();
  });
  tearDown(() async {
    await harness.dispose();
  });

  test(
    'demo seed loads a coherent history, budgets and rewards',
    () async {
      final seeded = await maybeDemoSeed(harness.store);
      expect(seeded, isTrue, reason: 'DEMO_SEED define should enable the seed');

      // --- history -----------------------------------------------------
      final txnRepo = HiveTransactionRepository(
        harness.store.transactions,
        userId: kLocalUserId,
      );
      final txns = await txnRepo.getAll();
      expect(txns.length, greaterThan(200));
      expect(
        txns.where((t) => t.type == TransactionType.income),
        isNotEmpty,
        reason: 'demo history should include income',
      );

      // --- aggregate cache rebuilt from that history -----------------
      final aggRepo = HivePeriodAggregateRepository(
        harness.store.periodAggregates,
      );
      expect(await aggRepo.getAll(), isNotEmpty);
      expect(harness.store.meta.get(MetaKeys.aggregatesBuilt), isTrue);

      // --- three budgets, one in each warning state this month -------
      final now = DateTime.now();
      final budgets = await HiveBudgetRepository(
        harness.store.budgets,
        userId: kLocalUserId,
      ).getAll();
      expect(budgets, hasLength(3));

      final monthStart = DateTime(now.year, now.month, 1);
      int monthSpend(String categoryId) => txns
          .where(
            (t) =>
                !t.isDeleted &&
                t.type == TransactionType.expense &&
                t.categoryId == categoryId &&
                !t.date.isBefore(monthStart),
          )
          .fold(0, (sum, t) => sum + t.amountMinor);

      final levels = <BudgetLevel>{};
      for (final b in budgets) {
        final status = budgetStatusFromSpent(
          budget: b,
          spentMinor: monthSpend(b.categoryId!),
          now: now,
        );
        levels.add(status.level);
      }
      expect(
        levels,
        containsAll(<BudgetLevel>[
          BudgetLevel.safe,
          BudgetLevel.approaching,
          BudgetLevel.exceeded,
        ]),
        reason: 'demo should show a budget in every state',
      );

      // --- gamification ----------------------------------------------
      final game = await HiveGamificationStateRepository(
        harness.store.gamificationState,
        userId: kLocalUserId,
      ).get();
      expect(game, isNotNull);
      expect(game!.unlockedBadgeIds.length, greaterThanOrEqualTo(5));
      expect(game.currentStreak, greaterThan(0));
      expect(game.xp, greaterThan(0));

      // --- idempotent -----------------------------------------------
      expect(await maybeDemoSeed(harness.store), isFalse);
    },
    skip: _enabled ? false : 'run with --dart-define=DEMO_SEED=true',
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/data/local/models/budget_model.dart';
import 'package:spendify/data/local/models/category_model.dart';
import 'package:spendify/data/local/models/gamification_state_model.dart';
import 'package:spendify/data/local/models/period_aggregate_model.dart';
import 'package:spendify/data/local/models/transaction_model.dart';
import 'package:spendify/data/local/user_id_migration.dart';
import 'package:spendify/domain/entities/enums.dart';

import '../../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness harness;
  final now = DateTime.utc(2027, 1, 15, 9);
  const realUid = 'firebase-uid-abc123';

  TransactionModel txn(String id, {String userId = kLocalUserId}) =>
      TransactionModel(
        id: id,
        userId: userId,
        amountMinor: 1500,
        type: TransactionType.expense,
        categoryId: 'cat-1',
        date: DateTime.utc(2026, 12, 1),
        source: TransactionSource.manual,
        createdAt: DateTime.utc(2026, 12, 1),
        updatedAt: DateTime.utc(2026, 12, 1),
        isDeleted: false,
        syncStatus: SyncStatus.synced,
      );

  CategoryModel cat(String id, {String userId = kLocalUserId}) => CategoryModel(
    id: id,
    userId: userId,
    name: 'Food',
    iconCode: 1,
    colorValue: 1,
    isDefault: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    isDeleted: false,
    syncStatus: SyncStatus.synced,
  );

  BudgetModel budget(String id, {String userId = kLocalUserId}) => BudgetModel(
    id: id,
    userId: userId,
    categoryId: null,
    limitAmountMinor: 50000,
    period: BudgetPeriod.monthly,
    startDate: DateTime.utc(2026, 12, 1),
    createdAt: DateTime.utc(2026, 12, 1),
    updatedAt: DateTime.utc(2026, 12, 1),
    isDeleted: false,
    syncStatus: SyncStatus.synced,
  );

  UserIdMigration subject() => UserIdMigration(harness.store, clock: () => now);

  Future<void> seedPlaceholderData() async {
    await harness.store.transactions.put('t1', txn('t1'));
    await harness.store.transactions.put('t2', txn('t2'));
    await harness.store.categories.put('c1', cat('c1'));
    await harness.store.budgets.put('b1', budget('b1'));
    await harness.store.gamificationState.put(
      kLocalUserId,
      GamificationStateModel(
        userId: kLocalUserId,
        xp: 40,
        coins: 5,
        level: 2,
        currentStreak: 3,
        longestStreak: 3,
        unlockedBadgeIds: const ['first-log'],
        updatedAt: DateTime.utc(2026, 12, 30),
        syncStatus: SyncStatus.synced,
      ),
    );
    await harness.store.periodAggregates.put(
      '${kLocalUserId}_monthly_2026-12_all',
      PeriodAggregateModel(
        id: '${kLocalUserId}_monthly_2026-12_all',
        userId: kLocalUserId,
        periodType: PeriodType.monthly,
        periodKey: '2026-12',
        totalIncomeMinor: 0,
        totalExpenseMinor: 3000,
        transactionCount: 2,
        updatedAt: DateTime.utc(2026, 12, 30),
      ),
    );
    await harness.store.meta.put(MetaKeys.aggregatesBuilt, true);
  }

  setUp(() async => harness = await HiveTestHarness.start());
  tearDown(() => harness.dispose());

  test('rewrites userId on every placeholder-owned record', () async {
    await seedPlaceholderData();

    final result = await subject().run(realUid: realUid);

    expect(result.complete, isTrue);
    // 2 txns + 1 category + 1 budget + 1 gamification row.
    expect(result.rewritten, 5);

    for (final m in harness.store.transactions.values) {
      expect(m.userId, realUid);
      expect(m.updatedAt, now); // bumped
      expect(m.syncStatus, SyncStatus.pending); // Phase 6 will pick it up
    }
    expect(harness.store.categories.get('c1')!.userId, realUid);
    expect(harness.store.categories.get('c1')!.syncStatus, SyncStatus.pending);
    expect(harness.store.budgets.get('b1')!.userId, realUid);

    // Gamification row is re-keyed from the placeholder to the real uid.
    expect(harness.store.gamificationState.get(kLocalUserId), isNull);
    final gs = harness.store.gamificationState.get(realUid);
    expect(gs, isNotNull);
    expect(gs!.userId, realUid);
    expect(gs.xp, 40); // data preserved
    expect(gs.syncStatus, SyncStatus.pending);

    // Aggregate cache is dropped for a rebuild (ids embed the uid).
    expect(harness.store.periodAggregates.isEmpty, isTrue);
    expect(
      harness.store.meta.get(MetaKeys.aggregatesBuilt),
      anyOf(isNull, isFalse),
    );

    // Completion flag recorded.
    expect(harness.store.meta.get(MetaKeys.userIdMigratedTo), realUid);
  });

  test('running it twice is a no-op', () async {
    await seedPlaceholderData();

    await subject().run(realUid: realUid);
    final t1AfterFirst = harness.store.transactions.get('t1')!.updatedAt;

    final second = await subject().run(realUid: realUid);

    expect(second.rewritten, 0);
    expect(second.complete, isTrue);
    // Nothing re-touched on the second pass.
    expect(harness.store.transactions.get('t1')!.updatedAt, t1AfterFirst);
    expect(
      harness.store.transactions.values.every((m) => m.userId == realUid),
      isTrue,
    );
  });

  test('an interrupted run is completed by the next launch', () async {
    await seedPlaceholderData();

    // Simulate a crash mid-migration: some records already re-keyed, the
    // completion flag never written.
    await harness.store.transactions.put('t1', txn('t1', userId: realUid));
    expect(harness.store.meta.get(MetaKeys.userIdMigratedTo), isNull);

    final result = await subject().run(realUid: realUid);

    expect(result.complete, isTrue);
    // t1 was already done; t2 + category + budget + gamification finished now.
    expect(result.rewritten, 4);
    expect(
      harness.store.transactions.values.every((m) => m.userId == realUid),
      isTrue,
    );
    expect(harness.store.categories.get('c1')!.userId, realUid);
    expect(harness.store.gamificationState.get(realUid), isNotNull);
    expect(harness.store.meta.get(MetaKeys.userIdMigratedTo), realUid);
  });

  test('is a no-op when there is nothing placeholder-owned', () async {
    await harness.store.transactions.put('t1', txn('t1', userId: realUid));

    final result = await subject().run(realUid: realUid);

    expect(result.rewritten, 0);
    expect(result.complete, isTrue);
    expect(harness.store.meta.get(MetaKeys.userIdMigratedTo), realUid);
  });

  test('rejects the placeholder as a target uid', () async {
    expect(() => subject().run(realUid: kLocalUserId), throwsArgumentError);
    expect(() => subject().run(realUid: ''), throwsArgumentError);
  });

  test('refuses to re-key data already owned by a different uid', () async {
    await seedPlaceholderData();
    await subject().run(realUid: realUid);

    expect(
      () => subject().run(realUid: 'a-different-uid'),
      throwsA(isA<StateError>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/repositories/hive_advice_record_repository.dart';
import 'package:spendly/data/repositories/hive_gamification_state_repository.dart';
import 'package:spendly/data/repositories/hive_period_aggregate_repository.dart';
import 'package:spendly/domain/entities/advice_record.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';

import '../../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness harness;
  final now = DateTime.utc(2026, 9, 6, 12);

  setUp(() async => harness = await HiveTestHarness.start());
  tearDown(() => harness.dispose());

  group('GamificationState repository', () {
    test(
      'getOrCreate mints a zeroed row, then persists edits with stamps',
      () async {
        final repo = HiveGamificationStateRepository(
          harness.store.gamificationState,
          clock: () => now,
        );

        final fresh = await repo.getOrCreate();
        expect(fresh.userId, kLocalUserId);
        expect(fresh.xp, 0);
        expect(fresh.level, 1);

        final saved = await repo.save(fresh.copyWith(xp: 40, coins: 5));
        expect(saved.xp, 40);
        expect(saved.updatedAt, now);
        expect(saved.syncStatus, SyncStatus.pending);

        // Survives a "restart": new repo instance, same box.
        final reread = await HiveGamificationStateRepository(
          harness.store.gamificationState,
        ).get();
        expect(reread!.xp, 40);
        expect(reread.coins, 5);
      },
    );

    test('there is only ever one row', () async {
      final repo = HiveGamificationStateRepository(
        harness.store.gamificationState,
      );
      await repo.getOrCreate();
      await repo.save((await repo.get())!.copyWith(xp: 1));
      await repo.save((await repo.get())!.copyWith(xp: 2));
      expect(harness.store.gamificationState.length, 1);
    });
  });

  test(
    'AdviceRecord repository caches by hash and returns the latest',
    () async {
      final repo = HiveAdviceRecordRepository(harness.store.adviceRecords);

      await repo.save(
        AdviceRecord(
          id: 'a1',
          userId: kLocalUserId,
          generatedAt: DateTime.utc(2026, 9, 1),
          summaryHash: 'hash-1',
          adviceItems: const ['Spend less on Food'],
        ),
      );
      await repo.save(
        AdviceRecord(
          id: 'a2',
          userId: kLocalUserId,
          generatedAt: DateTime.utc(2026, 9, 5),
          summaryHash: 'hash-2',
          adviceItems: const ['Nice work staying under budget'],
        ),
      );

      expect((await repo.getLatest())!.id, 'a2');
      expect((await repo.getBySummaryHash('hash-1'))!.id, 'a1');
      expect(await repo.getBySummaryHash('nope'), isNull);

      await repo.clear();
      expect(await repo.getLatest(), isNull);
    },
  );

  test('PeriodAggregate repository stores and queries by period', () async {
    final repo = HivePeriodAggregateRepository(harness.store.periodAggregates);

    PeriodAggregate agg(String key, {String? categoryId, int expense = 0}) {
      final id = PeriodAggregate.buildId(
        userId: kLocalUserId,
        periodType: PeriodType.monthly,
        periodKey: key,
        categoryId: categoryId,
      );
      return PeriodAggregate(
        id: id,
        userId: kLocalUserId,
        periodType: PeriodType.monthly,
        periodKey: key,
        categoryId: categoryId,
        totalIncomeMinor: 0,
        totalExpenseMinor: expense,
        transactionCount: 1,
        updatedAt: now,
      );
    }

    await repo.putAll([
      agg('2026-09', expense: 5000),
      agg('2026-09', categoryId: 'cat-food', expense: 3000),
      agg('2026-08', expense: 4000),
    ]);

    final september = await repo.getForPeriodKey(
      periodType: PeriodType.monthly,
      periodKey: '2026-09',
    );
    expect(september.length, 2);
    expect(
      await repo.getById(
        PeriodAggregate.buildId(
          userId: kLocalUserId,
          periodType: PeriodType.monthly,
          periodKey: '2026-08',
        ),
      ),
      isNotNull,
    );
    expect((await repo.getByPeriodType(PeriodType.monthly)).length, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/repositories/hive_budget_repository.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/patch.dart';

import '../../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness harness;
  late DateTime fakeNow;
  late HiveBudgetRepository repo;

  Budget sample({
    String id = 'b1',
    String? categoryId = 'cat-food',
    int limitAmountMinor = 30000,
  }) => Budget(
    id: id,
    userId: kLocalUserId,
    categoryId: categoryId,
    limitAmountMinor: limitAmountMinor,
    period: BudgetPeriod.monthly,
    startDate: DateTime.utc(2026, 9, 1),
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    syncStatus: SyncStatus.synced,
  );

  setUp(() async {
    harness = await HiveTestHarness.start();
    fakeNow = DateTime.utc(2026, 9, 6, 12);
    repo = HiveBudgetRepository(
      harness.store.budgets,
      userId: kLocalUserId,
      clock: () => fakeNow,
    );
  });

  tearDown(() => harness.dispose());

  test('CRUD round-trip through Hive', () async {
    final stored = await repo.add(sample());
    expect(await repo.getById('b1'), equals(stored));

    final raised = await repo.update(stored.copyWith(limitAmountMinor: 45000));
    expect(raised.limitAmountMinor, 45000);
    expect((await repo.getById('b1'))!.limitAmountMinor, 45000);

    await repo.delete('b1');
    expect(await repo.getById('b1'), isNull);
    expect(harness.store.budgets.containsKey('b1'), isTrue);
  });

  test('add stamps updatedAt + syncStatus = pending', () async {
    final stored = await repo.add(sample());
    expect(stored.updatedAt, fakeNow);
    expect(stored.syncStatus, SyncStatus.pending);
  });

  test('getOverall / getForCategory resolve the right live budget', () async {
    await repo.add(sample(id: 'cat', categoryId: 'cat-food'));
    await repo.add(sample(id: 'all', categoryId: null));

    expect((await repo.getOverall())!.id, 'all');
    expect((await repo.getForCategory('cat-food'))!.id, 'cat');
    expect(await repo.getForCategory('cat-transport'), isNull);

    await repo.delete('all');
    expect(await repo.getOverall(), isNull);
  });

  test('categoryId can be cleared to null via a patch', () async {
    final stored = await repo.add(sample(categoryId: 'cat-food'));
    final madeOverall = await repo.update(
      stored.copyWith(categoryId: patch<String?>(null)),
    );
    expect(madeOverall.categoryId, isNull);
    expect(madeOverall.isOverall, isTrue);
  });
}

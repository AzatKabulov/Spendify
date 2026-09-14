import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/domain/repositories/advice_generator_repository.dart';
import 'package:spendify/domain/services/advice_summary_builder.dart';
import 'package:spendify/data/repositories/advice_coordinator.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_sync.dart';

AdviceSummary _summary({int foodExpense = 50000}) => buildAdviceSummary(
  aggregates: <PeriodAggregate>[
    PeriodAggregate(
      id: 'total',
      userId: 'u',
      periodType: PeriodType.monthly,
      periodKey: '2026-09',
      totalIncomeMinor: 200000,
      totalExpenseMinor: foodExpense,
      transactionCount: 12,
      updatedAt: DateTime.utc(2026, 9, 15),
    ),
    PeriodAggregate(
      id: 'food',
      userId: 'u',
      periodType: PeriodType.monthly,
      periodKey: '2026-09',
      categoryId: 'cat-food',
      totalIncomeMinor: 0,
      totalExpenseMinor: foodExpense,
      transactionCount: 12,
      updatedAt: DateTime.utc(2026, 9, 15),
    ),
  ],
  budgets: const <Budget>[],
  categories: <Category>[
    Category.create(
      id: 'cat-food',
      userId: 'u',
      name: 'Food',
      iconCode: 0,
      colorValue: 0,
      now: DateTime.utc(2026, 1, 1),
    ),
  ],
  now: DateTime(2026, 9, 15),
);

void main() {
  late FakeAdviceRecordRepository cache;
  late FakeAdviceGenerator generator;
  late FakeConnectivityMonitor connectivity;
  var clockValue = DateTime.utc(2026, 9, 15, 10);

  AdviceCoordinator build() => AdviceCoordinator(
    generator: generator,
    cache: cache,
    connectivity: connectivity,
    userId: 'u',
    clock: () => clockValue,
    newId: () => 'advice-${cache.records.length}',
    refreshCooldown: const Duration(minutes: 3),
  );

  setUp(() {
    cache = FakeAdviceRecordRepository();
    generator = FakeAdviceGenerator();
    connectivity = FakeConnectivityMonitor();
    clockValue = DateTime.utc(2026, 9, 15, 10);
  });

  test('hash stability: identical summary hashes identically', () {
    expect(hashAdviceSummary(_summary()), hashAdviceSummary(_summary()));
  });

  test('hash changes when spending changes', () {
    expect(
      hashAdviceSummary(_summary(foodExpense: 50000)),
      isNot(hashAdviceSummary(_summary(foodExpense: 60000))),
    );
  });

  test(
    'first call generates and caches; second identical call does NOT',
    () async {
      final coordinator = build();

      final first = await coordinator.getAdvice(_summary());
      expect(first, isA<AdviceGenerated>());
      expect(generator.calls, 1);
      expect(cache.records, hasLength(1));

      final second = await coordinator.getAdvice(_summary());
      expect(second, isA<AdviceFromCache>());
      expect(
        generator.calls,
        1,
        reason: 'identical data must not call the API',
      );
    },
  );

  test('a real spending change regenerates (past the cooldown)', () async {
    final coordinator = build();
    await coordinator.getAdvice(_summary(foodExpense: 50000));
    expect(generator.calls, 1);

    clockValue = clockValue.add(const Duration(minutes: 5));
    final changed = await coordinator.getAdvice(_summary(foodExpense: 90000));
    expect(changed, isA<AdviceGenerated>());
    expect(generator.calls, 2);
  });

  test(
    'manual refresh within the cooldown is throttled, no API call',
    () async {
      final coordinator = build();
      await coordinator.getAdvice(_summary());
      expect(generator.calls, 1);

      clockValue = clockValue.add(const Duration(minutes: 1));
      final throttled = await coordinator.getAdvice(
        _summary(foodExpense: 99999),
        forceRefresh: true,
      );
      expect(throttled, isA<AdviceRefreshThrottled>());
      expect(generator.calls, 1);
    },
  );

  test('manual refresh past the cooldown regenerates', () async {
    final coordinator = build();
    await coordinator.getAdvice(_summary());

    clockValue = clockValue.add(const Duration(minutes: 4));
    final refreshed = await coordinator.getAdvice(
      _summary(),
      forceRefresh: true,
    );
    expect(refreshed, isA<AdviceGenerated>());
    expect(generator.calls, 2);
  });

  test(
    'offline + changed data -> returns the last cached record, no call',
    () async {
      final coordinator = build();
      await coordinator.getAdvice(_summary(foodExpense: 50000));
      expect(generator.calls, 1);

      connectivity.online = false;
      clockValue = clockValue.add(const Duration(minutes: 10));
      final outcome = await coordinator.getAdvice(_summary(foodExpense: 88000));

      expect(outcome, isA<AdviceOffline>());
      expect((outcome as AdviceOffline).lastRecord?.adviceItems, isNotEmpty);
      expect(generator.calls, 1);
    },
  );

  test('offline with no cache yet -> AdviceOffline(null)', () async {
    connectivity.online = false;
    final outcome = await build().getAdvice(_summary());
    expect(outcome, isA<AdviceOffline>());
    expect((outcome as AdviceOffline).lastRecord, isNull);
  });

  test(
    'generator failure -> AdviceError with the previous cache attached',
    () async {
      final coordinator = build();
      await coordinator.getAdvice(_summary(foodExpense: 50000));

      generator.failWith = const AdviceNetworkException();
      clockValue = clockValue.add(const Duration(minutes: 10));
      final outcome = await coordinator.getAdvice(_summary(foodExpense: 77000));

      expect(outcome, isA<AdviceError>());
      expect((outcome as AdviceError).lastRecord, isNotNull);
    },
  );

  test(
    'generated record carries the summary hash + structured items',
    () async {
      final outcome = await build().getAdvice(_summary()) as AdviceGenerated;
      expect(outcome.record.summaryHash, hashAdviceSummary(_summary()));
      expect(outcome.record.adviceItems.first, isA<AdviceItem>());
    },
  );
}

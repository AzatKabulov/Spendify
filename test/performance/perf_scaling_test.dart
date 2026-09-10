@Tags(['perf'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/local/models/transaction_model.dart';
import 'package:spendly/data/repositories/aggregation_maintenance.dart';
import 'package:spendly/data/repositories/hive_period_aggregate_repository.dart';
import 'package:spendly/data/repositories/hive_transaction_repository.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/domain/services/aggregation_service.dart';
import 'package:spendly/domain/services/balance_calculator.dart';
import 'package:spendly/domain/services/budget_evaluator.dart';
import 'package:spendly/domain/services/transaction_ordering.dart';

import '../support/hive_test_harness.dart';

/// Phase 11 Part B — performance evidence for the "core actions < 2 s"
/// commitment (CLAUDE.md §6). This test measures the *algorithmic* cost of the
/// operations behind each core screen against a realistic large dataset
/// (~5,000 transactions over 3 years, 15 categories), on the real encrypted
/// Hive stack. It runs on the Dart VM so it is reproducible in CI; the
/// on-device UI-render numbers are in `integration_test/performance_test.dart`.
///
/// Run:  flutter test test/performance/perf_scaling_test.dart
void main() {
  const seedCount = 5000;
  const runs = 5;
  const categoryCount = 15;

  late HiveTestHarness harness;
  final results = <_Result>[];

  setUpAll(() async {
    harness = await HiveTestHarness.start();
  });

  tearDownAll(() async {
    await harness.dispose();
    // ignore: avoid_print
    print(
      '\n${'=' * 74}\n'
      'PERFORMANCE — algorithmic cost, $seedCount txns / 3 years / '
      '$categoryCount categories\n'
      'Dart VM, ${DateTime.now().toIso8601String().substring(0, 10)}\n'
      '${'=' * 74}',
    );
    // ignore: avoid_print
    print(_Result.header());
    for (final r in results) {
      // ignore: avoid_print
      print(r);
    }
    // ignore: avoid_print
    print('=' * 74);
  });

  /// Times [op] [runs] times, records the median + worst, and asserts the
  /// median is under [budgetMs].
  Future<void> measure(
    String name,
    int budgetMs,
    Future<void> Function() op,
  ) async {
    final samples = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      await op();
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
    }
    samples.sort();
    final medianMs = samples[samples.length ~/ 2] / 1000.0;
    final worstMs = samples.last / 1000.0;
    results.add(_Result(name, budgetMs, medianMs, worstMs));
    expect(
      medianMs,
      lessThan(budgetMs),
      reason:
          '$name median ${medianMs.toStringAsFixed(1)}ms exceeds '
          '${budgetMs}ms budget',
    );
  }

  test('seed + core-action timings', () async {
    final txnRepo = HiveTransactionRepository(
      harness.store.transactions,
      userId: kLocalUserId,
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );
    final aggRepo = HivePeriodAggregateRepository(
      harness.store.periodAggregates,
    );
    final maintenance = AggregationMaintenance(
      aggRepo,
      userId: kLocalUserId,
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );

    // --- seed (bulk, not measured as a "core action") --------------------
    final rng = Random(42);
    final categoryIds = [for (var i = 0; i < categoryCount; i++) 'cat-$i'];
    final now = DateTime(2026, 9, 15);
    final models = <String, TransactionModel>{};
    for (var i = 0; i < seedCount; i++) {
      final daysAgo = rng.nextInt(365 * 3);
      final date = DateTime(now.year, now.month, now.day - daysAgo);
      final isIncome = rng.nextInt(12) == 0;
      models['t$i'] = TransactionModel(
        id: 't$i',
        userId: kLocalUserId,
        amountMinor: isIncome
            ? 150000 + rng.nextInt(400000)
            : 200 + rng.nextInt(20000),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: isIncome
            ? categoryIds.last
            : categoryIds[rng.nextInt(categoryCount - 1)],
        date: date,
        note: rng.nextInt(4) == 0 ? 'note $i' : null,
        source: TransactionSource.manual,
        createdAt: date,
        updatedAt: date,
        isDeleted: false,
        syncStatus: SyncStatus.pending,
      );
    }
    final seedSw = Stopwatch()..start();
    await harness.store.transactions.putAll(models);
    seedSw.stop();

    // --- 1. aggregate rebuild (first launch / after migration) -----------
    final allTxns = await txnRepo.getAll();
    expect(allTxns.length, seedCount);
    await measure('Rebuild all aggregates (one-off)', 2000, () async {
      await maintenance.rebuildAll(allTxns);
    });
    final aggCount = (await aggRepo.getAll()).length;

    // --- 2. load all aggregates from encrypted Hive ---------------------
    // Every report / home / budget open reads this list once.
    late List<PeriodAggregate> aggregates;
    await measure('Load PeriodAggregate cache ($aggCount rows)', 300, () async {
      aggregates = await aggRepo.getAll();
    });

    // --- 3. home screen: balance + totals from yearly aggregates -------
    await measure('Home balance + income/expense split', 50, () async {
      final yearly = aggregates.where(
        (a) => a.periodType == PeriodType.yearly && a.categoryId == null,
      );
      var inc = 0, exp = 0;
      for (final a in yearly) {
        inc += a.totalIncomeMinor;
        exp += a.totalExpenseMinor;
      }
      expect(inc - exp, isNot(0));
    });

    // --- 4. home screen: recent transaction list load + display sort ---
    await measure('Home recent-transactions list (load + sort)', 500, () async {
      final list = sortTransactionsForDisplay(await txnRepo.getAll());
      expect(list.length, seedCount);
    });

    // --- 5. monthly report: figures + category pie/breakdown -----------
    await measure('Open monthly report (figures + breakdown)', 100, () async {
      const key = '2026-09';
      PeriodAggregate? total;
      final cats = <PeriodAggregate>[];
      for (final a in aggregates) {
        if (a.periodType != PeriodType.monthly || a.periodKey != key) continue;
        if (a.categoryId == null) {
          total = a;
        } else {
          cats.add(a);
        }
      }
      cats.sort((x, y) => y.totalExpenseMinor.compareTo(x.totalExpenseMinor));
      expect(total, isNotNull);
    });

    // --- 6. monthly report: "spend over time" per-day bars ------------
    await measure('Report "spend over time" bars (monthly)', 100, () async {
      final bounds = periodBounds(PeriodType.monthly, '2026-09');
      final byDay = <String, int>{
        for (final a in aggregates)
          if (a.periodType == PeriodType.daily && a.categoryId == null)
            a.periodKey: a.totalExpenseMinor,
      };
      var bars = 0;
      for (
        var d = bounds.start;
        d.isBefore(bounds.end);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        byDay[periodKeyFor(d, PeriodType.daily)];
        bars++;
      }
      expect(bars, greaterThan(27));
    });

    // --- 7. yearly report ---------------------------------------------
    await measure('Open yearly report (12 monthly bars)', 100, () async {
      final byMonth = <String, int>{
        for (final a in aggregates)
          if (a.periodType == PeriodType.monthly && a.categoryId == null)
            a.periodKey: a.totalExpenseMinor,
      };
      for (var m = 1; m <= 12; m++) {
        byMonth['2026-${m.toString().padLeft(2, '0')}'];
      }
    });

    // --- 8. budget list: evaluate every budget's status ---------------
    final budgets = <Budget>[
      Budget.create(
        id: 'b-overall',
        userId: kLocalUserId,
        limitAmountMinor: 300000,
        period: BudgetPeriod.monthly,
        startDate: now,
        now: now,
      ),
      for (var i = 0; i < categoryCount; i++)
        Budget.create(
          id: 'b-$i',
          userId: kLocalUserId,
          categoryId: 'cat-$i',
          limitAmountMinor: 40000,
          period: i.isEven ? BudgetPeriod.monthly : BudgetPeriod.weekly,
          startDate: now,
          now: now,
        ),
    ];
    await measure(
      'Open budget list (${budgets.length} statuses)',
      100,
      () async {
        final byId = {for (final a in aggregates) a.id: a};
        for (final b in budgets) {
          final pt = b.period == BudgetPeriod.weekly
              ? PeriodType.weekly
              : PeriodType.monthly;
          final id = PeriodAggregate.buildId(
            userId: kLocalUserId,
            periodType: pt,
            periodKey: periodKeyFor(now, pt),
            categoryId: b.categoryId,
          );
          budgetStatusFromSpent(
            budget: b,
            spentMinor: byId[id]?.totalExpenseMinor ?? 0,
            now: now,
          );
        }
      },
    );

    // --- 9. save a transaction: incremental aggregate update ----------
    var n = 0;
    await measure(
      'Save a transaction (persist + aggregate update)',
      300,
      () async {
        final t = Transaction.create(
          id: 'new-${n++}',
          userId: kLocalUserId,
          amountMinor: 1234,
          type: TransactionType.expense,
          categoryId: 'cat-1',
          date: now,
          now: DateTime.utc(2026, 9, 15, 12),
        );
        await txnRepo.add(t);
        await maintenance.applyCreate(t);
      },
    );

    // --- 10. reference: full-scan balance (the pre-Phase-4 approach) --
    await measure(
      '[reference] balance by full transaction scan',
      2000,
      () async {
        calculateBalanceMinor(await txnRepo.getAll());
      },
    );

    // ignore: avoid_print
    print(
      '\nseed (bulk putAll, $seedCount rows): '
      '${(seedSw.elapsedMicroseconds / 1000).toStringAsFixed(0)}ms  '
      '(not a core action — measured for context)',
    );
  });
}

class _Result {
  _Result(this.name, this.budgetMs, this.medianMs, this.worstMs);

  final String name;
  final int budgetMs;
  final double medianMs;
  final double worstMs;

  bool get pass => medianMs < budgetMs;

  static String header() =>
      '${'action'.padRight(46)}'
      '${'budget'.padLeft(8)}${'median'.padLeft(9)}${'worst'.padLeft(9)}   ';

  @override
  String toString() =>
      '${name.padRight(46)}'
      '${'${budgetMs}ms'.padLeft(8)}'
      '${'${medianMs.toStringAsFixed(1)}ms'.padLeft(9)}'
      '${'${worstMs.toStringAsFixed(1)}ms'.padLeft(9)}'
      '   ${pass ? 'PASS' : 'FAIL'}';
}

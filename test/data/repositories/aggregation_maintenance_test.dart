import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/data/repositories/aggregation_maintenance.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/domain/services/aggregation_service.dart';

import '../../support/fake_repositories.dart';

const _userId = 'local-user';
final _now = DateTime.utc(2026, 9, 8, 12);

Transaction tx({
  required String id,
  required DateTime date,
  required TransactionType type,
  required int amountMinor,
  String categoryId = 'food',
  bool isDeleted = false,
}) => Transaction(
  id: id,
  userId: _userId,
  amountMinor: amountMinor,
  type: type,
  categoryId: categoryId,
  date: date,
  source: TransactionSource.manual,
  createdAt: date,
  updatedAt: date,
  isDeleted: isDeleted,
);

/// Compare two aggregate sets ignoring `updatedAt` (timestamps differ between
/// incremental writes and a rebuild).
void expectSameAggregates(
  Iterable<PeriodAggregate> a,
  Iterable<PeriodAggregate> b,
) {
  ({int i, int e, int c}) sig(PeriodAggregate x) =>
      (i: x.totalIncomeMinor, e: x.totalExpenseMinor, c: x.transactionCount);
  final ma = {for (final x in a) x.id: sig(x)};
  final mb = {for (final x in b) x.id: sig(x)};
  expect(ma, equals(mb));
}

void main() {
  late FakePeriodAggregateRepository repo;
  late AggregationMaintenance sut;

  setUp(() {
    repo = FakePeriodAggregateRepository();
    sut = AggregationMaintenance(repo, clock: () => _now, userId: _userId);
  });

  int expenseFor(PeriodType type, String periodKey, {String? categoryId}) {
    final id = PeriodAggregate.buildId(
      userId: _userId,
      periodType: type,
      periodKey: periodKey,
      categoryId: categoryId,
    );
    return repo.store[id]?.totalExpenseMinor ?? 0;
  }

  int monthlyExpense(String periodKey, {String? categoryId}) =>
      expenseFor(PeriodType.monthly, periodKey, categoryId: categoryId);

  int dailyExpense(String periodKey, {String? categoryId}) =>
      expenseFor(PeriodType.daily, periodKey, categoryId: categoryId);

  test('create adds exactly the amount to all eight aggregates', () async {
    await sut.applyCreate(
      tx(
        id: 't1',
        date: DateTime(2026, 9, 10),
        type: TransactionType.expense,
        amountMinor: 2500,
      ),
    );

    // 4 period types (daily/weekly/monthly/yearly) x {category, total}.
    expect(repo.store.length, 8);
    expect(monthlyExpense('2026-09'), 2500);
    expect(monthlyExpense('2026-09', categoryId: 'food'), 2500);
    expect(dailyExpense('2026-09-10'), 2500);
    expect(dailyExpense('2026-09-10', categoryId: 'food'), 2500);
    for (final agg in repo.store.values) {
      expect(agg.totalExpenseMinor, 2500);
      expect(agg.transactionCount, 1);
    }
  });

  test(
    'soft delete returns every aggregate to the prior value (row removed)',
    () async {
      final t = tx(
        id: 't1',
        date: DateTime(2026, 9, 10),
        type: TransactionType.expense,
        amountMinor: 2500,
      );
      await sut.applyCreate(t);
      await sut.applyDelete(t);
      expect(repo.store, isEmpty);
    },
  );

  test('undo delete restores the post-create value', () async {
    final t = tx(
      id: 't1',
      date: DateTime(2026, 9, 10),
      type: TransactionType.expense,
      amountMinor: 2500,
    );
    await sut.applyCreate(t);
    await sut.applyDelete(t);
    await sut.applyCreate(t); // undo == create
    expect(monthlyExpense('2026-09'), 2500);
    expect(dailyExpense('2026-09-10'), 2500);
    expect(repo.store.length, 8);
  });

  test('edit amount only updates the single set of buckets', () async {
    final before = tx(
      id: 't1',
      date: DateTime(2026, 9, 10),
      type: TransactionType.expense,
      amountMinor: 2500,
    );
    await sut.applyCreate(before);
    final after = before.copyWith(amountMinor: 4000);
    await sut.applyEdit(before: before, after: after);

    expect(monthlyExpense('2026-09'), 4000);
    expect(dailyExpense('2026-09-10'), 4000);
    expect(repo.store.length, 8);
  });

  test('edit category: old category down, new up, total unchanged', () async {
    final before = tx(
      id: 't1',
      date: DateTime(2026, 9, 10),
      type: TransactionType.expense,
      amountMinor: 3000,
      categoryId: 'food',
    );
    await sut.applyCreate(before);
    final after = before.copyWith(categoryId: 'transport');
    await sut.applyEdit(before: before, after: after);

    expect(monthlyExpense('2026-09', categoryId: 'food'), 0);
    expect(monthlyExpense('2026-09', categoryId: 'transport'), 3000);
    expect(monthlyExpense('2026-09'), 3000); // period total unchanged
  });

  test(
    'EDIT DATE ACROSS A PERIOD BOUNDARY moves the amount between periods',
    () async {
      final before = tx(
        id: 't1',
        date: DateTime(2026, 9, 30),
        type: TransactionType.expense,
        amountMinor: 5000,
      );
      await sut.applyCreate(before);
      expect(monthlyExpense('2026-09'), 5000);
      expect(monthlyExpense('2026-10'), 0);

      final after = before.copyWith(date: DateTime(2026, 10, 1));
      await sut.applyEdit(before: before, after: after);

      expect(monthlyExpense('2026-09'), 0);
      expect(monthlyExpense('2026-10'), 5000);
      // weekly moved too: 2026-09-30 is W40, 2026-10-01 is W40 as well... use a
      // clearer week jump instead:
    },
  );

  test('edit date across a WEEK boundary moves the weekly aggregate', () async {
    final before = tx(
      id: 't1',
      date: DateTime(2026, 9, 13), // Sunday, ISO W37
      type: TransactionType.expense,
      amountMinor: 800,
    );
    await sut.applyCreate(before);

    final after = before.copyWith(date: DateTime(2026, 9, 14)); // Monday, W38
    await sut.applyEdit(before: before, after: after);

    int weekExpense(String key) {
      final id = PeriodAggregate.buildId(
        userId: _userId,
        periodType: PeriodType.weekly,
        periodKey: key,
      );
      return repo.store[id]?.totalExpenseMinor ?? 0;
    }

    expect(weekExpense('2026-W37'), 0);
    expect(weekExpense('2026-W38'), 800);
  });

  test(
    'EDIT DATE ACROSS A DAY BOUNDARY moves the daily aggregate (23rd -> 24th)',
    () async {
      final before = tx(
        id: 't1',
        date: DateTime(2026, 9, 23),
        type: TransactionType.expense,
        amountMinor: 1200,
      );
      await sut.applyCreate(before);
      expect(dailyExpense('2026-09-23'), 1200);
      expect(dailyExpense('2026-09-23', categoryId: 'food'), 1200);
      expect(dailyExpense('2026-09-24'), 0);

      final after = before.copyWith(date: DateTime(2026, 9, 24));
      await sut.applyEdit(before: before, after: after);

      expect(dailyExpense('2026-09-23'), 0);
      expect(dailyExpense('2026-09-23', categoryId: 'food'), 0);
      expect(dailyExpense('2026-09-24'), 1200);
      expect(dailyExpense('2026-09-24', categoryId: 'food'), 1200);
      // Same day is still in Sep / W39 / 2026, so those are untouched.
      expect(monthlyExpense('2026-09'), 1200);
      // The emptied daily rows are removed, not left at zero.
      expect(
        repo.store.containsKey(
          PeriodAggregate.buildId(
            userId: _userId,
            periodType: PeriodType.daily,
            periodKey: '2026-09-23',
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'after ~60 random create/edit/delete ops, incremental == rebuildAll',
    () async {
      final rng = Random(20260908);
      final categories = ['food', 'transport', 'bills', 'fun'];
      final live = <String, Transaction>{};
      final deleted = <String, Transaction>{};
      var seq = 0;

      DateTime randomDate() => DateTime(
        2025 + rng.nextInt(3),
        1 + rng.nextInt(12),
        1 + rng.nextInt(28),
      );
      Transaction randomTx(String id) => tx(
        id: id,
        date: randomDate(),
        type: rng.nextInt(4) == 0
            ? TransactionType.income
            : TransactionType.expense,
        amountMinor: 100 + rng.nextInt(50000),
        categoryId: categories[rng.nextInt(categories.length)],
      );

      for (var op = 0; op < 60; op++) {
        final roll = rng.nextInt(10);
        if (roll < 5 || live.isEmpty) {
          // create
          final t = randomTx('t${seq++}');
          live[t.id] = t;
          await sut.applyCreate(t);
        } else if (roll < 8) {
          // edit a random live transaction
          final id = live.keys.elementAt(rng.nextInt(live.length));
          final before = live[id]!;
          final after = before.copyWith(
            amountMinor: 100 + rng.nextInt(50000),
            categoryId: categories[rng.nextInt(categories.length)],
            date: randomDate(),
          );
          live[id] = after;
          await sut.applyEdit(before: before, after: after);
        } else if (deleted.isNotEmpty && rng.nextBool()) {
          // undo a delete: the row is live again, so it's an applyCreate of
          // the (non-deleted) transaction — same as TransactionActions.restore.
          final id = deleted.keys.elementAt(rng.nextInt(deleted.length));
          final t = deleted.remove(id)!;
          live[id] = t;
          await sut.applyCreate(t);
        } else {
          // delete a random live transaction
          final id = live.keys.elementAt(rng.nextInt(live.length));
          final t = live.remove(id)!;
          deleted[id] = t;
          await sut.applyDelete(t);
        }
      }

      final rebuilt = computeAggregates(
        transactions: live.values,
        userId: _userId,
        now: _now,
      );
      expectSameAggregates(repo.store.values, rebuilt);

      // And an explicit rebuildAll agrees too.
      await sut.rebuildAll(live.values);
      expectSameAggregates(repo.store.values, rebuilt);
    },
  );

  test('rebuildAll wipes and recomputes from scratch', () async {
    // Seed some garbage.
    await repo.put(
      PeriodAggregate(
        id: 'garbage',
        userId: _userId,
        periodType: PeriodType.monthly,
        periodKey: '1999-01',
        totalIncomeMinor: 999,
        totalExpenseMinor: 999,
        transactionCount: 9,
        updatedAt: _now,
      ),
    );
    await sut.rebuildAll([
      tx(
        id: 't1',
        date: DateTime(2026, 9, 10),
        type: TransactionType.expense,
        amountMinor: 1000,
      ),
    ]);
    expect(repo.store.containsKey('garbage'), isFalse);
    expect(monthlyExpense('2026-09'), 1000);
  });
}

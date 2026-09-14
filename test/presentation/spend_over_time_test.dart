import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/providers/report_providers.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';

import '../support/widget_test_scaffold.dart';

/// Phase 4.1: the weekly/monthly "spend over time" bars now read from the daily
/// `PeriodAggregate`s instead of scanning the viewed period's transactions.
/// These tests pin the bar values to what the old transaction scan produced —
/// i.e. for each day, the sum of that day's non-deleted expense transactions.
Transaction _exp(
  String id,
  int minor,
  DateTime date, {
  String category = 'cat-0',
}) => Transaction.create(
  id: id,
  userId: kLocalUserId,
  amountMinor: minor,
  type: TransactionType.expense,
  categoryId: category,
  date: date,
  now: DateTime.utc(2026, 9, 8, 12),
);

void main() {
  testWidgets(
    'monthly: one bar per calendar day, expense-only, in-period-only',
    (tester) async {
      // pumpSpendify pins "now" to 2026-09-15 -> monthly view of September 2026.
      final repos = await pumpSpendify(tester, home: const ReportsScreen());

      await repos.seedTransaction(_exp('a', 5000, DateTime(2026, 9, 3)));
      await repos.seedTransaction(
        _exp('b', 2000, DateTime(2026, 9, 3)),
      ); // same day
      await repos.seedTransaction(_exp('c', 3000, DateTime(2026, 9, 10)));
      await repos.seedTransaction(_exp('d', 1500, DateTime(2026, 9, 28)));
      // Income on a day in-period -> must not show on the (expense) bars.
      await repos.seedTransaction(
        Transaction.create(
          id: 'inc',
          userId: kLocalUserId,
          amountMinor: 90000,
          type: TransactionType.income,
          categoryId: 'cat-0',
          date: DateTime(2026, 9, 3),
          now: DateTime.utc(2026, 9, 8, 12),
        ),
      );
      // Expense in a different month -> must not show in the September view.
      await repos.seedTransaction(_exp('aug', 4242, DateTime(2026, 8, 20)));
      await tester.pumpAndSettle();

      final bars = repos.container.read(spendOverTimeProvider);

      expect(bars.length, 30); // September has 30 days
      expect(bars[0].label, '1');
      expect(bars[29].label, '30');

      final byLabel = {for (final b in bars) b.label: b.expenseMinor};
      expect(byLabel['3'], 7000); // 5000 + 2000, income excluded
      expect(byLabel['10'], 3000);
      expect(byLabel['28'], 1500);
      // every other day is zero
      final nonZero = bars
          .where((b) => b.expenseMinor != 0)
          .map((b) => b.label);
      expect(nonZero, unorderedEquals(<String>['3', '10', '28']));

      // Total across the bars equals the September expense total.
      final barsTotal = bars.fold<int>(0, (s, b) => s + b.expenseMinor);
      expect(barsTotal, 11500);
    },
  );

  testWidgets('weekly: 7 bars for the Mon–Sun window, from daily aggregates', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const ReportsScreen());

    // 2026-09-15 is a Tuesday -> ISO week 38 -> Mon 14 Sep .. Sun 20 Sep.
    await repos.seedTransaction(_exp('t', 2500, DateTime(2026, 9, 15)));
    await repos.seedTransaction(_exp('th', 800, DateTime(2026, 9, 17)));
    await repos.seedTransaction(_exp('sun', 400, DateTime(2026, 9, 20)));
    // Just outside the week on both sides.
    await repos.seedTransaction(_exp('before', 999, DateTime(2026, 9, 13)));
    await repos.seedTransaction(_exp('after', 999, DateTime(2026, 9, 21)));
    await tester.pumpAndSettle();

    repos.container
        .read(reportSelectionProvider.notifier)
        .setType(PeriodType.weekly);
    await tester.pumpAndSettle();

    final bars = repos.container.read(spendOverTimeProvider);
    expect(bars.length, 7);
    expect(bars.map((b) => b.label), <String>[
      '14',
      '15',
      '16',
      '17',
      '18',
      '19',
      '20',
    ]);
    expect(bars[1].expenseMinor, 2500); // Tue 15th
    expect(bars[3].expenseMinor, 800); // Thu 17th
    expect(bars[6].expenseMinor, 400); // Sun 20th
    expect(
      bars.where((b) => b.expenseMinor != 0).map((b) => b.label),
      unorderedEquals(<String>['15', '17', '20']),
    );
  });

  testWidgets('editing a transaction moves its bar to the new day', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const ReportsScreen());
    final saved = await repos.seedTransaction(
      _exp('m', 6000, DateTime(2026, 9, 10)),
    );
    await tester.pumpAndSettle();

    var bars = repos.container.read(spendOverTimeProvider);
    expect({for (final b in bars) b.label: b.expenseMinor}['10'], 6000);

    // Same pattern as TransactionActions.edit: reverse the old, apply the new.
    final moved = saved.copyWith(date: DateTime(2026, 9, 11));
    await repos.transactions.update(moved);
    await repos.maintenance.applyEdit(before: saved, after: moved);
    await tester.pumpAndSettle();

    bars = repos.container.read(spendOverTimeProvider);
    final byLabel = {for (final b in bars) b.label: b.expenseMinor};
    expect(byLabel['10'], 0);
    expect(byLabel['11'], 6000);
  });
}

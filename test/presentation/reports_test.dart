import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';

import '../support/widget_test_scaffold.dart';

Transaction _txn(
  String id, {
  required int minor,
  required TransactionType type,
  required String category,
  required DateTime date,
}) => Transaction.create(
  id: id,
  userId: kLocalUserId,
  amountMinor: minor,
  type: type,
  categoryId: category,
  date: date,
  now: DateTime.utc(2026, 9, 8, 12),
);

void main() {
  testWidgets('renders the summary, pie and breakdown for a period with data', (
    tester,
  ) async {
    // Local clock is pinned to 2026-09-15, so the screen opens on Sep 2026
    // (monthly). Seed income + two expense categories inside that month.
    final repos = await pumpSpendify(tester, home: const ReportsScreen());

    await repos.seedTransaction(
      _txn(
        't-income',
        minor: 20000,
        type: TransactionType.income,
        category: 'cat-0',
        date: DateTime(2026, 9, 5),
      ),
    );
    await repos.seedTransaction(
      _txn(
        't-food',
        minor: 5000,
        type: TransactionType.expense,
        category: 'cat-0', // Food
        date: DateTime(2026, 9, 10),
      ),
    );
    await repos.seedTransaction(
      _txn(
        't-transport',
        minor: 3000,
        type: TransactionType.expense,
        category: 'cat-1', // Transport
        date: DateTime(2026, 9, 12),
      ),
    );
    await tester.pumpAndSettle();

    // Summary header figures come straight from the cached aggregate.
    expect(find.text('RM 200.00'), findsOneWidget); // income
    expect(find.text('RM 80.00'), findsOneWidget); // total expense

    // Sections that only appear when there is spend.
    expect(find.text('Where it went'), findsOneWidget);
    expect(find.text('Spending over time'), findsOneWidget);

    // The empty state must NOT be showing.
    expect(find.text('No transactions this period'), findsNothing);

    // "Next" is disabled because we are already on the current month.
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(nextButton.onPressed, isNull);

    // Category breakdown lives below the fold — scroll it into view. Largest
    // first, with names + amounts.
    final listView = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Food'),
      200,
      scrollable: listView,
    );
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('RM 50.00'), findsOneWidget);
    expect(find.text('RM 30.00'), findsOneWidget);
  });

  testWidgets('shows a clear empty state for a period with no transactions', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const ReportsScreen());
    await tester.pumpAndSettle();

    expect(find.text('No transactions this period'), findsOneWidget);
    expect(
      find.text('Use the arrows above to look at another week, month or year.'),
      findsOneWidget,
    );

    // None of the data sections render.
    expect(find.text('By category'), findsNothing);
    expect(find.text('Where it went'), findsNothing);
  });

  testWidgets('navigating to a previous empty period shows the empty state', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const ReportsScreen());
    await repos.seedTransaction(
      _txn(
        't-food',
        minor: 5000,
        type: TransactionType.expense,
        category: 'cat-0',
        date: DateTime(2026, 9, 10),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No transactions this period'), findsNothing);

    // Step back to August 2026 — nothing was logged there.
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions this period'), findsOneWidget);

    // And forward again restores the populated view.
    await tester.tap(find.byTooltip('Next period'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions this period'), findsNothing);
    expect(find.text('RM 50.00'), findsOneWidget);
  });
}

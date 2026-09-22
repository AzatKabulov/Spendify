import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/category_breakdown_screen.dart';
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

/// Opens the period picker sheet — where the prev/next arrows now live.
/// Taps the chip's icon rather than the widget: `PeriodChip` is a left-aligned
/// pill inside a full-width `Align`, so the widget's centre is off the pill.
Future<void> _openPeriodPicker(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calendar_today_outlined));
  await tester.pumpAndSettle();
}

/// The arrow button carrying [tooltip] inside the period picker sheet.
Finder _arrow(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

void main() {
  testWidgets('renders the overview figures for a period with data', (
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

    // The period the screen opened on, and the headline figures — all
    // straight from the cached aggregates.
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Total Spending'), findsOneWidget);
    // Twice: the headline figure, and the label on the current trend bar.
    expect(find.text('RM 80.00'), findsWidgets); // total expense
    expect(find.text('RM 200.00'), findsOneWidget); // income
    expect(find.text('RM 120.00'), findsOneWidget); // net

    // The empty state must NOT be showing.
    expect(find.text('No transactions this period'), findsNothing);

    // Top categories, largest first, with names + amounts.
    expect(find.text('Top Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('RM 50.00'), findsOneWidget);
    expect(find.text('RM 30.00'), findsOneWidget);

    // "Next" is disabled because we are already on the current month.
    await _openPeriodPicker(tester);
    final next = tester.widget<IconButton>(_arrow('Next period'));
    expect(next.onPressed, isNull);
  });

  testWidgets('shows a clear empty state for a period with no transactions', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const ReportsScreen());
    await tester.pumpAndSettle();

    expect(find.text('No transactions this period'), findsOneWidget);
    expect(
      find.text('Pick another week, month or year to look at.'),
      findsOneWidget,
    );

    // None of the data sections render.
    expect(find.text('Total Spending'), findsNothing);
    expect(find.text('Top Categories'), findsNothing);
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
    await _openPeriodPicker(tester);
    await tester.tap(_arrow('Previous period'));
    await tester.pumpAndSettle();
    // Both the chip behind the sheet and the sheet's own label.
    expect(find.text('August 2026'), findsWidgets);

    await tester.tap(_arrow('Next period'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump to today'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions this period'), findsNothing);
    expect(find.text('RM 50.00'), findsWidgets);
  });

  testWidgets('the Categories tab opens the breakdown screen', (tester) async {
    await pumpSpendify(tester, home: const ReportsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryBreakdownScreen), findsOneWidget);
    expect(find.text('Category Breakdown'), findsOneWidget);
  });
}

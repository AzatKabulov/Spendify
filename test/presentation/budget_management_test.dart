import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/presentation/screens/budget_form_screen.dart';
import 'package:spendly/presentation/screens/budgets_screen.dart';
import 'package:spendly/presentation/screens/home_screen.dart';

import '../support/widget_test_scaffold.dart';

Budget overallMonthly(int limitMinor) => Budget(
  id: 'existing',
  userId: kLocalUserId,
  categoryId: null,
  limitAmountMinor: limitMinor,
  period: BudgetPeriod.monthly,
  startDate: DateTime(2026, 9, 1),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

Transaction sepExpense(String id, int minor, {String category = 'c'}) =>
    Transaction.create(
      id: id,
      userId: kLocalUserId,
      amountMinor: minor,
      type: TransactionType.expense,
      categoryId: category,
      date: DateTime(2026, 9, 10),
      now: DateTime.utc(2026, 9, 10),
    );

void main() {
  testWidgets('rejects a limit of zero', (tester) async {
    await pumpSpendly(tester, home: const BudgetFormScreen());

    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Limit must be greater than zero'), findsOneWidget);
  });

  testWidgets('rejects an unparseable limit', (tester) async {
    await pumpSpendly(tester, home: const BudgetFormScreen());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Limit'),
      '12.999',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('rejects a duplicate (scope, period) budget', (tester) async {
    final repos = await pumpSpendly(tester, home: const BudgetFormScreen());
    await repos.budgets.add(overallMonthly(50000));
    await tester.pumpAndSettle();

    // Form defaults to Overall + Monthly — same as the one we just added.
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already'), findsWidgets);
    // The form did not pop and nothing new was created.
    expect(find.byType(BudgetFormScreen), findsOneWidget);
    expect((await repos.budgets.getAll()).length, 1);
  });

  testWidgets('creates a valid budget and lists it', (tester) async {
    final repos = await pumpSpendly(tester, home: const BudgetsScreen());

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final all = await repos.budgets.getAll();
    expect(all.single.limitAmountMinor, 50000);
    expect(all.single.isOverall, isTrue);
    expect(find.text('Overall'), findsOneWidget);
  });

  testWidgets('home shows a warning banner once a budget is exceeded', (
    tester,
  ) async {
    final repos = await pumpSpendly(tester, home: const HomeScreen());
    await repos.budgets.add(overallMonthly(10000)); // RM 100 monthly

    await repos.transactions.add(sepExpense('e1', 6000));
    await tester.pumpAndSettle();
    // 60% used -> safe, no banner
    expect(find.textContaining('budget'), findsNothing);

    await repos.transactions.add(sepExpense('e2', 5000)); // now 110%
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.textContaining('over its monthly limit'), findsOneWidget);
  });
}

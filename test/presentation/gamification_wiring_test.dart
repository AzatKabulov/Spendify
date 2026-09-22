import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/widgets/home/home_sections.dart';
import 'package:spendify/presentation/screens/transaction_form_screen.dart';

import '../support/widget_test_scaffold.dart';

/// End-to-end: the Transaction layer raises events, the runner processes them,
/// and the home screen surfaces the reward — without ever blocking the write.
void main() {
  Transaction seed(String id, {String note = 'seed'}) => Transaction.create(
    id: id,
    userId: kLocalUserId,
    amountMinor: 2500,
    type: TransactionType.expense,
    categoryId: 'cat-0',
    date: DateTime(2026, 9, 8),
    now: DateTime.utc(2026, 9, 8),
    note: note,
  );

  testWidgets('adding a transaction awards XP and shows a reward', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '12.00',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pumpAndSettle();

    // form popped, we're back on home
    expect(find.byType(TransactionFormScreen), findsNothing);

    final state = await repos.gamification.get();
    expect(state, isNotNull);
    expect(state!.transactionsLogged, 1);
    expect(state.xp, greaterThan(0));

    // the feedback SnackBar (badge unlock takes priority over the XP line)
    expect(find.textContaining('First Steps'), findsOneWidget);
  });

  testWidgets('swipe-delete reverses the logged XP', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());

    // log through the form so the engine actually awards it
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '20.00',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pumpAndSettle();

    final awardedXp = (await repos.gamification.get())!.xp;
    expect(awardedXp, greaterThan(0));

    // Scope to the transaction row: the reward snackbar is a Dismissible too.
    await tester.drag(
      find.descendant(
        of: find.byType(RecentTransactionsCard),
        matching: find.byType(Dismissible),
      ),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    final afterDelete = (await repos.gamification.get())!.xp;
    expect(afterDelete, lessThan(awardedXp));
  });

  testWidgets('a pre-existing seed does not double-count on load', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());
    // seeding bypasses TransactionActions -> no gamification event
    await repos.seedTransaction(seed('s1'));
    await tester.pumpAndSettle();

    final state = await repos.gamification.get();
    expect(state?.transactionsLogged ?? 0, 0);
  });
}

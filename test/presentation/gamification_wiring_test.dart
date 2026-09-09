import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/presentation/screens/home_screen.dart';
import 'package:spendly/presentation/screens/transaction_form_screen.dart';
import 'package:spendly/presentation/widgets/transaction_list_tile.dart';

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
    final repos = await pumpSpendly(tester, home: const HomeScreen());

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
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
    final repos = await pumpSpendly(tester, home: const HomeScreen());

    // log through the form so the engine actually awards it
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
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

    await tester.drag(find.byType(TransactionListTile), const Offset(-600, 0));
    await tester.pumpAndSettle();

    final afterDelete = (await repos.gamification.get())!.xp;
    expect(afterDelete, lessThan(awardedXp));
  });

  testWidgets('a pre-existing seed does not double-count on load', (
    tester,
  ) async {
    final repos = await pumpSpendly(tester, home: const HomeScreen());
    // seeding bypasses TransactionActions -> no gamification event
    await repos.seedTransaction(seed('s1'));
    await tester.pumpAndSettle();

    final state = await repos.gamification.get();
    expect(state?.transactionsLogged ?? 0, 0);
  });
}

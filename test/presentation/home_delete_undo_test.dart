import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import '../support/widget_test_scaffold.dart';

Transaction sampleTxn({
  String id = 'txn-seed',
  int amountMinor = 2500,
  TransactionType type = TransactionType.expense,
  String note = 'Lunch canary',
}) => Transaction.create(
  id: id,
  userId: kLocalUserId,
  amountMinor: amountMinor,
  type: type,
  categoryId: 'cat-0',
  date: DateTime(2026, 9, 6),
  now: DateTime.utc(2026, 9, 6),
  note: note,
);

void main() {
  testWidgets('empty state shows before any transaction', (tester) async {
    await pumpSpendify(tester, home: const HomeScreen());
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('a seeded transaction appears in the list', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());
    await repos.seedTransaction(sampleTxn());
    await tester.pumpAndSettle();

    expect(find.textContaining('Lunch canary'), findsOneWidget);
    expect(find.text('No transactions yet'), findsNothing);
  });

  testWidgets('swipe deletes the row; UNDO restores it', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());
    await repos.seedTransaction(sampleTxn());
    await tester.pumpAndSettle();

    await tester.drag(
      find.textContaining('Lunch canary'),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Lunch canary'), findsNothing);
    expect(find.text('Transaction deleted'), findsOneWidget);
    expect(await repos.transactions.getById('txn-seed'), isNull);
    // still physically present as a tombstone
    expect(
      await repos.transactions.getByIdIncludingDeleted('txn-seed'),
      isNotNull,
    );

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lunch canary'), findsOneWidget);
    expect(await repos.transactions.getById('txn-seed'), isNotNull);
  });

  testWidgets('balance = income − expense, formatted', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());
    await repos.seedTransaction(
      sampleTxn(id: 'i', type: TransactionType.income, amountMinor: 100000),
    );
    await repos.seedTransaction(
      sampleTxn(id: 'e1', amountMinor: 25000, note: 'a'),
    );
    await repos.seedTransaction(
      sampleTxn(id: 'e2', amountMinor: 15000, note: 'b'),
    );
    await tester.pumpAndSettle();

    // 1000.00 − 250.00 − 150.00 = 600.00
    expect(find.text('RM 600.00'), findsOneWidget);
  });

  testWidgets('tapping a row opens the edit form pre-filled', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());
    await repos.seedTransaction(sampleTxn(amountMinor: 4200));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Lunch canary'));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('42.00'), findsOneWidget); // amount pre-filled
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/presentation/screens/transaction_form_screen.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  Future<void> enterAmount(WidgetTester tester, String text) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      text,
    );
    await tester.pump();
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Add transaction');

  testWidgets('rejects an empty amount', (tester) async {
    await pumpSpendify(tester, home: const TransactionFormScreen());

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('valid amount'), findsOneWidget);
  });

  testWidgets('rejects a zero amount', (tester) async {
    await pumpSpendify(tester, home: const TransactionFormScreen());

    await enterAmount(tester, '0');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Amount must be greater than zero'), findsOneWidget);
  });

  testWidgets('rejects an unparseable amount (>2 dp)', (tester) async {
    await pumpSpendify(tester, home: const TransactionFormScreen());

    await enterAmount(tester, '12.999');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('valid amount'), findsOneWidget);
  });

  testWidgets('saves a valid transaction and pops', (tester) async {
    final repos = await pumpSpendify(tester, home: const _FormHost());

    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '15.50',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormScreen), findsNothing); // popped

    final all = await repos.transactions.getAll();
    expect(all, hasLength(1));
    expect(all.single.amountMinor, 1550);
    expect(all.single.type, TransactionType.expense); // default
    expect(all.single.source, TransactionSource.manual);
    expect(all.single.date, DateTime(2026, 9, 8)); // today, date-only
  });

  testWidgets('note is optional — saves with a null note', (tester) async {
    final repos = await pumpSpendify(tester, home: const _FormHost());
    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '9',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pumpAndSettle();

    final all = await repos.transactions.getAll();
    expect(all.single.note, isNull);
  });

  testWidgets('remembers the chosen category as last-used', (tester) async {
    final repos = await pumpSpendify(tester, home: const _FormHost());
    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount').first,
      '5',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pumpAndSettle();

    final saved = (await repos.transactions.getAll()).single;
    expect(repos.preferences.lastUsedCategoryId, saved.categoryId);
  });
}

/// A tiny host so we can verify the form pops after saving.
class _FormHost extends StatelessWidget {
  const _FormHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransactionFormScreen(),
              ),
            ),
            child: const Text('open form'),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/categories_screen.dart';
import 'package:spendify/presentation/screens/category_form_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  testWidgets('rejects a duplicate category name (case-insensitive)', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const CategoryFormScreen());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'food', // "Food" is a seeded default
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOneWidget);
  });

  testWidgets('creates a new category', (tester) async {
    final repos = await pumpSpendify(tester, home: const CategoriesScreen());

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Coffee',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final all = await repos.categories.getAll();
    expect(all.any((c) => c.name == 'Coffee'), isTrue);
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('a default category cannot be deleted (locked action)', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const CategoriesScreen());

    final foodRow = find.ancestor(
      of: find.text('Food'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: foodRow, matching: find.byIcon(Icons.lock_outline)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: foodRow, matching: find.byIcon(Icons.delete_outline)),
      findsNothing,
    );
  });

  testWidgets('deleting a category keeps its transactions rendering with the '
      'category name + icon', (tester) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());

    // A custom (deletable) category with a transaction.
    final coffee = await repos.categories.add(
      Category.create(
        id: 'cat-coffee',
        userId: kLocalUserId,
        name: 'Coffee',
        iconCode: 0xe541,
        colorValue: 0xFF6D4C41,
        now: DateTime.utc(2026, 9, 1),
      ),
    );
    await repos.seedTransaction(
      Transaction.create(
        id: 't-coffee',
        userId: kLocalUserId,
        amountMinor: 1200,
        type: TransactionType.expense,
        categoryId: coffee.id,
        date: DateTime(2026, 9, 10),
        now: DateTime.utc(2026, 9, 10),
        note: 'Flat white',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);

    // Delete the category directly through the repo (soft delete).
    await repos.categories.delete(coffee.id);
    await tester.pumpAndSettle();

    // The transaction row still shows the (now deleted) category's name.
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining('Flat white'), findsOneWidget);
  });
}

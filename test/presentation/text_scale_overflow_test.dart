// Phase 12 Part C — accessibility: every main screen must stay usable at 200%
// system text scale with no layout overflow. A RenderFlex (or other layout)
// overflow reports through `FlutterError.onError` during the pump rather than
// being thrown at the call site, so it is captured there instead of relying on
// `tester.takeException()` alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/screens/auth/sign_in_screen.dart';
import 'package:spendify/presentation/screens/budgets_screen.dart';
import 'package:spendify/presentation/screens/categories_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';
import 'package:spendify/presentation/screens/settings_screen.dart';
import 'package:spendify/presentation/screens/stats_screen.dart';
import 'package:spendify/presentation/screens/transaction_form_screen.dart';

import '../support/widget_test_scaffold.dart';

Transaction _txn(
  String id, {
  required int minor,
  required TransactionType type,
  required String category,
  required DateTime date,
  String? note,
}) => Transaction.create(
  id: id,
  userId: kLocalUserId,
  amountMinor: minor,
  type: type,
  categoryId: category,
  date: date,
  note: note,
  now: DateTime.utc(2026, 9, 8, 12),
);

void main() {
  Future<void> seedSome(TestRepos repos) async {
    await repos.seedTransaction(_txn(
      'a',
      minor: 1234567, // RM 12,345.67 — a wide number, worst case for the header
      type: TransactionType.income,
      category: 'cat-7',
      date: DateTime(2026, 9, 3),
      note: 'Part-time work payment for August',
    ));
    await repos.seedTransaction(_txn(
      'b',
      minor: 8900,
      type: TransactionType.expense,
      category: 'cat-0',
      date: DateTime(2026, 9, 12),
      note: 'Lunch with a fairly long note attached to it',
    ));
    await repos.seedTransaction(_txn(
      'c',
      minor: 45000,
      type: TransactionType.expense,
      category: 'cat-2',
      date: DateTime(2026, 9, 13),
    ));
  }

  for (final entry in <String, Widget Function()>{
    'Home': HomeScreen.new,
    'Reports': ReportsScreen.new,
    'Budgets': BudgetsScreen.new,
    'Categories': CategoriesScreen.new,
    'Rewards': StatsScreen.new,
    'Settings': SettingsScreen.new,
    'Add transaction': TransactionFormScreen.new,
    'Sign in': SignInScreen.new,
  }.entries) {
    testWidgets('${entry.key} has no overflow at 200% text scale', (
      tester,
    ) async {
      // A layout overflow reports via `FlutterError.onError` during the pump,
      // not as a thrown exception at the call site — capture it directly
      // rather than relying on `tester.takeException()` alone.
      final errors = <String>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.toStringShort());
        prevOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = prevOnError);

      final repos = await pumpSpendify(
        tester,
        home: entry.value(),
        textScale: 2.0,
      );
      await seedSome(repos);
      await tester.pumpAndSettle();

      tester.takeException();
      expect(
        errors,
        isEmpty,
        reason: '${entry.key} overflows at 2x text scale: $errors',
      );
    });
  }
}

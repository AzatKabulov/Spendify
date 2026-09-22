import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/presentation/screens/budgets_screen.dart';
import 'package:spendify/presentation/screens/categories_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';
import 'package:spendify/presentation/screens/settings_screen.dart';
import 'package:spendify/presentation/screens/stats_screen.dart';
import 'package:spendify/presentation/screens/transactions_screen.dart';

import '../support/widget_test_scaffold.dart';

/// Regression guard for how you get around from Home: the bottom navigation
/// and the quick-action tiles. (These replaced the old AppBar buttons and
/// overflow menu, which an earlier over-broad `git checkout` once silently
/// reverted — so navigation is asserted explicitly.)
void main() {
  Finder inNav(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('bottom navigation and quick actions are present', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const HomeScreen());

    for (final label in <String>[
      'Home',
      'Transactions',
      'Budgets',
      'Reports',
      'Profile',
    ]) {
      expect(inNav(label), findsOneWidget, reason: label);
    }
    // Insights is not a tab — the fourth slot is Reports.
    expect(inNav('Insights'), findsNothing);

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // "Reports" is both a tab and a quick-action shortcut to it.
    expect(find.text('Reports'), findsNWidgets(2));
  });

  testWidgets('each tab opens its screen', (tester) async {
    await pumpSpendify(tester, home: const HomeScreen());

    await tester.tap(inNav('Transactions'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionsScreen), findsOneWidget);

    await tester.tap(inNav('Budgets'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetsScreen), findsOneWidget);

    await tester.tap(inNav('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);

    await tester.tap(inNav('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('quick actions route to Reports, Categories and Rewards', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const HomeScreen());

    // The Reports quick action switches to the Reports tab rather than
    // pushing a second copy over the shell.
    await tester.tap(find.byIcon(Icons.insights));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    await tester.tap(inNav('Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
    // CategoriesScreen uses the custom FormHeader, not a Material AppBar, so
    // there is no standard BackButton for tester.pageBack() to find.
    Navigator.of(tester.element(find.byType(CategoriesScreen))).pop();
    await tester.pumpAndSettle();

    // With AI off the second tile is Rewards.
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
  });
}

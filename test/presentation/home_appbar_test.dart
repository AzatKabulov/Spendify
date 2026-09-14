import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/presentation/screens/budgets_screen.dart';
import 'package:spendify/presentation/screens/categories_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';
import 'package:spendify/presentation/screens/settings_screen.dart';

import '../support/widget_test_scaffold.dart';

/// Regression guard for the home-screen AppBar. It was silently reverted once
/// by an over-broad `git checkout` during Phase 4 clean-up and had to be
/// reconstructed by hand. These assertions fail loudly if the Reports action
/// or the Settings menu entry disappears again.
///
/// Everything is found by tooltip / menu text scoped to the AppBar — not by
/// tree position — so ordinary layout tweaks don't make it brittle.
void main() {
  Finder inAppBar(Finder matching) =>
      find.descendant(of: find.byType(AppBar), matching: matching);

  testWidgets(
    'AppBar exposes Reports, Budgets and a Categories/Settings menu',
    (tester) async {
      await pumpSpendify(tester, home: const HomeScreen());

      // Direct navigation actions.
      expect(inAppBar(find.byTooltip('Reports')), findsOneWidget);
      expect(inAppBar(find.byTooltip('Budgets')), findsOneWidget);
      expect(
        inAppBar(find.byIcon(Icons.bar_chart_outlined)),
        findsOneWidget,
        reason: 'Reports action icon',
      );

      // The overflow menu holds Categories + Settings.
      final menu = inAppBar(find.byType(PopupMenuButton<int>));
      expect(menu, findsOneWidget);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  testWidgets('each AppBar action routes to its screen', (tester) async {
    await pumpSpendify(tester, home: const HomeScreen());

    await tester.tap(inAppBar(find.byTooltip('Reports')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(inAppBar(find.byTooltip('Budgets')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(inAppBar(find.byType(PopupMenuButton<int>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(inAppBar(find.byType(PopupMenuButton<int>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });
}

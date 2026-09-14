import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/providers/budget_providers.dart';
import 'package:spendify/presentation/screens/budgets_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/widgets/budget_warning_banner.dart';

import '../support/widget_test_scaffold.dart';

/// Phase 11 Part A — full journey: add spending → set a budget → exceed it →
/// the home warning banner appears → it routes to the budget list showing the
/// overspent budget. Exercises Transaction Manager, Budget Manager,
/// AggregationMaintenance and the report/budget providers together.
void main() {
  testWidgets('add transactions → set budget → exceed → see the warning', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const HomeScreen());

    // 1. the user logs three lunches this month (RM 180 total on cat-0)
    for (var i = 0; i < 3; i++) {
      await repos.seedTransaction(
        Transaction.create(
          id: 'lunch-$i',
          userId: kLocalUserId,
          amountMinor: 6000,
          type: TransactionType.expense,
          categoryId: 'cat-0',
          date: DateTime(2026, 9, 5 + i),
          now: DateTime.utc(2026, 9, 10),
        ),
      );
    }
    await tester.pumpAndSettle();

    // no budget yet -> no warning banner
    expect(find.byType(BudgetWarningBanner), findsOneWidget);
    expect(
      tester
          .widget<BudgetWarningBanner>(find.byType(BudgetWarningBanner))
          .warnings,
      isEmpty,
    );

    // 2. they set an overall monthly budget of RM 150 (already exceeded)
    await repos.container
        .read(budgetActionsProvider)
        .create(
          categoryId: null,
          limitAmountMinor: 15000,
          period: BudgetPeriod.monthly,
        );
    await tester.pumpAndSettle();

    // 3. the home banner now warns
    final banner = tester.widget<BudgetWarningBanner>(
      find.byType(BudgetWarningBanner),
    );
    expect(banner.warnings, isNotEmpty);
    expect(banner.warnings.first.isExceeded, isTrue);
    expect(find.textContaining('over its monthly limit'), findsOneWidget);

    // 4. tapping the banner opens the budget list, which shows the overspend
    await tester.tap(find.byType(BudgetWarningBanner));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetsScreen), findsOneWidget);
    expect(find.textContaining('over'), findsWidgets);
  });
}

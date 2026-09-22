import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/presentation/screens/advice_detail_screen.dart';

import '../support/widget_test_scaffold.dart';

PeriodAggregate _monthTotal(
  String key, {
  required int expense,
  int income = 0,
}) => PeriodAggregate(
  id: PeriodAggregate.buildId(
    userId: kLocalUserId,
    periodType: PeriodType.monthly,
    periodKey: key,
  ),
  userId: kLocalUserId,
  periodType: PeriodType.monthly,
  periodKey: key,
  totalIncomeMinor: income,
  totalExpenseMinor: expense,
  transactionCount: 5,
  updatedAt: DateTime.utc(2026, 9, 15),
);

PeriodAggregate _monthCategory(
  String key,
  String categoryId, {
  required int expense,
}) => PeriodAggregate(
  id: PeriodAggregate.buildId(
    userId: kLocalUserId,
    periodType: PeriodType.monthly,
    periodKey: key,
    categoryId: categoryId,
  ),
  userId: kLocalUserId,
  periodType: PeriodType.monthly,
  periodKey: key,
  categoryId: categoryId,
  totalIncomeMinor: 0,
  totalExpenseMinor: expense,
  transactionCount: 3,
  updatedAt: DateTime.utc(2026, 9, 15),
);

void main() {
  const item = AdviceItem(
    title: "You're spending less",
    body: 'Your spending fell by 12% compared with August 2026.',
    type: AdviceItemType.spending,
  );

  testWidgets('shows the tapped insight plus the real month comparison', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceDetailScreen(item: item),
    );
    // Clock is pinned to 2026-09-15 -> this month is 2026-09, last is 2026-08.
    await repos.aggregates.putAll(<PeriodAggregate>[
      _monthTotal('2026-08', expense: 209120),
      _monthTotal('2026-09', expense: 184230),
      _monthCategory('2026-08', 'cat-0', expense: 18000),
      _monthCategory('2026-09', 'cat-0', expense: 14000),
    ]);
    await tester.pumpAndSettle();

    // The title/body appear twice: the insight card at the top, and again in
    // "Gemini's take" further down — the same real text, not fabricated.
    expect(find.text(item.title), findsNWidgets(2));
    expect(find.textContaining(item.body), findsNWidgets(2));
    expect(find.text('This month vs last'), findsOneWidget);
    // Twice: the headline figure, and the chart's own label on the current
    // bar (the same pairing Reports uses for its Total Spending card).
    expect(find.text('RM 1,842.30'), findsWidgets);
    expect(find.textContaining('RM 2,091.20'), findsOneWidget);

    expect(find.text('What changed?'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget); // cat-0's real name
    expect(find.textContaining('−RM 40.00'), findsOneWidget);
  });

  testWidgets('a brand-new category shows "new this month", not -100%', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceDetailScreen(item: item),
    );
    await repos.aggregates.putAll(<PeriodAggregate>[
      _monthTotal('2026-09', expense: 5000),
      _monthCategory('2026-09', 'cat-1', expense: 5000),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('new this month'), findsOneWidget);
  });

  testWidgets('no fabricated sentiment badge is shown', (tester) async {
    await pumpSpendify(tester, home: const AdviceDetailScreen(item: item));
    // Neither of the mockup's badge words appears anywhere on the screen —
    // nothing in the data honestly classifies free-text advice as good or
    // bad news, so the badge is omitted rather than guessed.
    expect(find.text('Positive'), findsNothing);
    expect(find.text('Negative'), findsNothing);
  });

  testWidgets("Gemini's take re-shows the same item, not a second call", (
    tester,
  ) async {
    await pumpSpendify(tester, home: const AdviceDetailScreen(item: item));
    // Title appears twice: once at the top, once in the "Gemini's take" card.
    expect(find.text(item.title), findsNWidgets(2));
  });
}

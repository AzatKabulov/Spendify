import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/advice_record.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/presentation/providers/advice_providers.dart';
import 'package:spendify/presentation/screens/advice_detail_screen.dart';
import 'package:spendify/presentation/screens/advice_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import '../support/widget_test_scaffold.dart';

PeriodAggregate _agg(
  PeriodType type,
  String key, {
  String? categoryId,
  int expense = 0,
  int income = 0,
  int count = 1,
}) => PeriodAggregate(
  id: PeriodAggregate.buildId(
    userId: kLocalUserId,
    periodType: type,
    periodKey: key,
    categoryId: categoryId,
  ),
  userId: kLocalUserId,
  periodType: type,
  periodKey: key,
  categoryId: categoryId,
  totalIncomeMinor: income,
  totalExpenseMinor: expense,
  transactionCount: count,
  updatedAt: DateTime.utc(2026, 9, 15),
);

/// Enough logged history for advice to be worthwhile (>= 10 lifetime), then
/// (re)runs the screen's load — the screen loads once in initState, so a test
/// that seeds afterwards simulates re-opening it.
Future<void> _seedEnoughData(WidgetTester tester, TestRepos repos) async {
  await repos.aggregates.putAll(<PeriodAggregate>[
    _agg(PeriodType.yearly, '2026', income: 300000, expense: 120000, count: 15),
    _agg(
      PeriodType.monthly,
      '2026-09',
      income: 150000,
      expense: 60000,
      count: 15,
    ),
    _agg(
      PeriodType.monthly,
      '2026-09',
      categoryId: 'cat-0',
      expense: 40000,
      count: 10,
    ),
  ]);
  // let the aggregate stream propagate before the controller reads it
  await tester.pumpAndSettle();
  await repos.container.read(adviceControllerProvider.notifier).load();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('under 10 transactions: honest empty state, no API call', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Keep logging'), findsOneWidget);
    expect(repos.adviceGenerator.calls, 0);
  });

  testWidgets(
    'with data: generates once, shows cards + disclaimer + timestamp',
    (tester) async {
      final repos = await pumpSpendify(
        tester,
        home: const AdviceScreen(),
        geminiApiKey: 'test-key',
      );
      await _seedEnoughData(tester, repos);
      await tester.pumpAndSettle();

      expect(repos.adviceGenerator.calls, 1);
      expect(find.textContaining('Ease off Food'), findsOneWidget);
      expect(
        find.textContaining('Not financial advice.'),
        findsOneWidget,
        reason: 'disclaimer must be visible with the advice',
      );
      expect(find.textContaining('Generated'), findsOneWidget);
    },
  );

  testWidgets('viewing twice with unchanged data makes ONE API call', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
    );
    await _seedEnoughData(tester, repos);
    await tester.pumpAndSettle();
    expect(repos.adviceGenerator.calls, 1);

    // simulate re-opening the screen
    await repos.container.read(adviceControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(
      repos.adviceGenerator.calls,
      1,
      reason: 'identical summary hash must be served from cache',
    );
  });

  testWidgets('offline with cached advice: shows it with an offline note', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
      online: false,
    );
    repos.adviceCache.records.add(
      AdviceRecord(
        id: 'old',
        userId: kLocalUserId,
        generatedAt: DateTime.utc(2026, 9, 1),
        summaryHash: 'stale-hash',
        adviceItems: const [
          AdviceItem(title: 'Saved tip', body: 'Batch your grocery trips.'),
        ],
      ),
    );
    await _seedEnoughData(tester, repos);
    await tester.pumpAndSettle();

    expect(find.textContaining('Batch your grocery trips.'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(repos.adviceGenerator.calls, 0);
  });

  testWidgets('offline, no cache yet: honest message, not an error screen', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
      online: false,
    );
    await _seedEnoughData(tester, repos);
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(repos.adviceGenerator.calls, 0);
  });

  testWidgets('the type tabs filter Key Insights; "For You" shows everything', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
    );
    repos.adviceGenerator.next = const [
      AdviceItem(
        title: 'Ease off Food',
        body: '…',
        type: AdviceItemType.spending,
      ),
      AdviceItem(
        title: 'Great savings month',
        body: '…',
        type: AdviceItemType.saving,
      ),
    ];
    await _seedEnoughData(tester, repos);
    await tester.pumpAndSettle();

    expect(find.text('Ease off Food'), findsOneWidget);
    expect(find.text('Great savings month'), findsOneWidget);

    await tester.tap(find.text('Saving'));
    await tester.pumpAndSettle();
    expect(find.text('Ease off Food'), findsNothing);
    expect(find.text('Great savings month'), findsOneWidget);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    expect(find.text('Ease off Food'), findsOneWidget);
    expect(find.text('Great savings month'), findsOneWidget);
  });

  testWidgets('tapping an insight opens its detail screen', (tester) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceScreen(),
      geminiApiKey: 'test-key',
    );
    await _seedEnoughData(tester, repos);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ease off Food a little'));
    await tester.pumpAndSettle();

    expect(find.byType(AdviceDetailScreen), findsOneWidget);
  });

  // Insights is not a bottom-nav tab: the fourth slot is Reports, as in the
  // approved mockup. The AI entry points are the Home AI card and
  // Reports -> Trends -> Insights.
  testWidgets('the Home AI card opens Insights when configured', (
    tester,
  ) async {
    await pumpSpendify(
      tester,
      home: const HomeScreen(),
      geminiApiKey: 'test-key',
    );
    await tester.pumpAndSettle();

    final card = find.text('Spendify AI');
    expect(card, findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(AdviceScreen), findsOneWidget);
  });

  testWidgets('no AI entry point at all when no API key is configured', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const HomeScreen());
    await tester.pumpAndSettle();

    expect(find.text('Spendify AI'), findsNothing);

    final nav = find.byType(NavigationBar);
    expect(
      find.descendant(of: nav, matching: find.text('Insights')),
      findsNothing,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Reports')),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/domain/entities/advice_item.dart';
import 'package:spendly/domain/entities/advice_record.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';
import 'package:spendly/presentation/providers/advice_providers.dart';
import 'package:spendly/presentation/screens/advice_screen.dart';
import 'package:spendly/presentation/screens/home_screen.dart';

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
    final repos = await pumpSpendly(
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
      final repos = await pumpSpendly(
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
      expect(find.textContaining('Last updated'), findsOneWidget);
    },
  );

  testWidgets('viewing twice with unchanged data makes ONE API call', (
    tester,
  ) async {
    final repos = await pumpSpendly(
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
    final repos = await pumpSpendly(
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
    final repos = await pumpSpendly(
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

  testWidgets('"Insights" appears in the home menu when configured', (
    tester,
  ) async {
    await pumpSpendly(
      tester,
      home: const HomeScreen(),
      geminiApiKey: 'test-key',
    );

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Insights'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.byType(AdviceScreen), findsOneWidget);
  });

  testWidgets('"Insights" is hidden when no API key is configured', (
    tester,
  ) async {
    await pumpSpendly(tester, home: const HomeScreen());

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Insights'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
}

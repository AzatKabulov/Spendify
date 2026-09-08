import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/data/repositories/aggregation_maintenance.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/presentation/providers/repository_providers.dart';

import 'fake_repositories.dart';

/// The in-memory repositories a pumped test is running against.
class TestRepos {
  TestRepos({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.aggregates,
    required this.preferences,
    required this.maintenance,
  });

  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeBudgetRepository budgets;
  final FakePeriodAggregateRepository aggregates;
  final FakeAppPreferences preferences;
  final AggregationMaintenance maintenance;

  /// Add a transaction the way `TransactionActions` does — persist it **and**
  /// update the aggregate cache (which the balance / budget providers read).
  Future<Transaction> seedTransaction(Transaction txn) async {
    final saved = await transactions.add(txn);
    await maintenance.applyCreate(saved);
    return saved;
  }
}

/// Pumps [home] inside a `MaterialApp` + `ProviderScope` wired to fast,
/// synchronous in-memory repositories (default categories pre-seeded). Widget
/// tests exercise the UI + providers + actions; the Hive layer has its own
/// tests under `test/data/`.
///
/// Storage clock is pinned to 2026-09-08 12:00 UTC; the local ("now") clock is
/// pinned to [now] (default 2026-09-15, a Tuesday). New ids are `id-0`, `id-1`…
Future<TestRepos> pumpSpendly(
  WidgetTester tester, {
  required Widget home,
  DateTime? now,
}) async {
  final txnRepo = FakeTransactionRepository();
  final catRepo = FakeCategoryRepository();
  final budgetRepo = FakeBudgetRepository();
  final aggRepo = FakePeriodAggregateRepository();
  final prefs = FakeAppPreferences();
  await catRepo.ensureDefaultsSeeded();
  final localNow = now ?? DateTime(2026, 9, 15, 10);
  final maintenance = AggregationMaintenance(
    aggRepo,
    clock: () => DateTime.utc(2026, 9, 8, 12),
  );

  var idSeq = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(txnRepo),
        categoryRepositoryProvider.overrideWithValue(catRepo),
        budgetRepositoryProvider.overrideWithValue(budgetRepo),
        periodAggregateRepositoryProvider.overrideWithValue(aggRepo),
        appPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 8, 12)),
        localTimeProvider.overrideWithValue(() => localNow),
        idGeneratorProvider.overrideWithValue(() => 'id-${idSeq++}'),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return TestRepos(
    transactions: txnRepo,
    categories: catRepo,
    budgets: budgetRepo,
    aggregates: aggRepo,
    preferences: prefs,
    maintenance: maintenance,
  );
}

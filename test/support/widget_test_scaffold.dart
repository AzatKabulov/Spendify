import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/presentation/providers/repository_providers.dart';

import 'fake_repositories.dart';

/// The in-memory repositories a pumped test is running against.
class TestRepos {
  TestRepos(this.transactions, this.categories, this.budgets, this.preferences);

  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeBudgetRepository budgets;
  final FakeAppPreferences preferences;
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
  final prefs = FakeAppPreferences();
  await catRepo.ensureDefaultsSeeded();
  final localNow = now ?? DateTime(2026, 9, 15, 10);

  var idSeq = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(txnRepo),
        categoryRepositoryProvider.overrideWithValue(catRepo),
        budgetRepositoryProvider.overrideWithValue(budgetRepo),
        appPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 8, 12)),
        localTimeProvider.overrideWithValue(() => localNow),
        idGeneratorProvider.overrideWithValue(() => 'id-${idSeq++}'),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return TestRepos(txnRepo, catRepo, budgetRepo, prefs);
}

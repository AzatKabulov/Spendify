import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/presentation/providers/repository_providers.dart';
import 'package:spendly/presentation/providers/transaction_providers.dart';

import 'fake_repositories.dart';

/// The in-memory repositories a pumped test is running against.
class TestRepos {
  TestRepos(this.transactions, this.categories, this.preferences);

  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeAppPreferences preferences;
}

/// Pumps [home] inside a `MaterialApp` + `ProviderScope` wired to fast,
/// synchronous in-memory repositories (default categories pre-seeded). Widget
/// tests exercise the UI + providers + [TransactionActions]; the Hive layer has
/// its own tests under `test/data/`.
///
/// Clock is pinned to 2026-09-08 12:00 UTC and new transaction ids are
/// `txn-0`, `txn-1`, … so assertions are deterministic.
Future<TestRepos> pumpSpendly(
  WidgetTester tester, {
  required Widget home,
}) async {
  final txnRepo = FakeTransactionRepository();
  final catRepo = FakeCategoryRepository();
  final prefs = FakeAppPreferences();
  await catRepo.ensureDefaultsSeeded();

  var idSeq = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(txnRepo),
        categoryRepositoryProvider.overrideWithValue(catRepo),
        appPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 8, 12)),
        idGeneratorProvider.overrideWithValue(() => 'txn-${idSeq++}'),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return TestRepos(txnRepo, catRepo, prefs);
}

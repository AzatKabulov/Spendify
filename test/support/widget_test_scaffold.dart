import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/core/theme/app_theme.dart';
import 'package:spendly/data/repositories/aggregation_maintenance.dart';
import 'package:spendly/domain/entities/ai_consent.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/presentation/providers/advice_providers.dart';
import 'package:spendly/presentation/providers/ai_providers.dart';
import 'package:spendly/presentation/providers/auth_providers.dart';
import 'package:spendly/presentation/providers/privacy_providers.dart';
import 'package:spendly/presentation/providers/repository_providers.dart';
import 'package:spendly/presentation/providers/sync_providers.dart';

import 'fake_repositories.dart';
import 'fake_sync.dart';

/// The in-memory repositories a pumped test is running against.
class TestRepos {
  TestRepos({
    required this.container,
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.aggregates,
    required this.preferences,
    required this.maintenance,
    required this.gamification,
    required this.adviceCache,
    required this.adviceGenerator,
    required this.connectivity,
    required this.aiPrefs,
    required this.wiper,
  });

  /// The pumped app's `ProviderContainer`, for reading providers directly
  /// (e.g. `container.read(spendOverTimeProvider)`).
  final ProviderContainer container;
  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeBudgetRepository budgets;
  final FakePeriodAggregateRepository aggregates;
  final FakeAppPreferences preferences;
  final AggregationMaintenance maintenance;
  final FakeGamificationStateRepository gamification;
  final FakeAdviceRecordRepository adviceCache;
  final FakeAdviceGenerator adviceGenerator;
  final FakeConnectivityMonitor connectivity;
  final FakeAiPreferencesStore aiPrefs;
  final FakeLocalDataWiper wiper;

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
  String geminiApiKey = '',
  bool online = true,
  AiConsent aiConsent = AiConsent.granted,

  /// When true, also overrides `sessionProvider` with a ready signed-in
  /// session — needed when [home] is `AuthGate` so it routes past sign-in.
  bool signedInSession = false,

  /// System text scale to render at. 1.0 is normal; the accessibility pass
  /// (Phase 12 Part C) pumps screens at 2.0 to check for overflow.
  double textScale = 1.0,
}) async {
  final txnRepo = FakeTransactionRepository();
  final catRepo = FakeCategoryRepository();
  final budgetRepo = FakeBudgetRepository();
  final aggRepo = FakePeriodAggregateRepository();
  final prefs = FakeAppPreferences();
  final gamificationRepo = FakeGamificationStateRepository(
    userId: kLocalUserId,
    clock: () => DateTime.utc(2026, 9, 8, 12),
  );
  final adviceCache = FakeAdviceRecordRepository();
  final adviceGenerator = FakeAdviceGenerator();
  final connectivity = FakeConnectivityMonitor(startOnline: online);
  final aiPrefs = FakeAiPreferencesStore(aiConsent);
  final wiper = FakeLocalDataWiper(
    transactions: txnRepo,
    categories: catRepo,
    budgets: budgetRepo,
    aggregates: aggRepo,
    gamification: gamificationRepo,
    adviceCache: adviceCache,
  );
  addTearDown(connectivity.close);
  await catRepo.ensureDefaultsSeeded();
  final localNow = now ?? DateTime(2026, 9, 15, 10);
  final maintenance = AggregationMaintenance(
    aggRepo,
    userId: kLocalUserId,
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
        gamificationStateRepositoryProvider.overrideWithValue(gamificationRepo),
        adviceRecordRepositoryProvider.overrideWithValue(adviceCache),
        adviceGeneratorRepositoryProvider.overrideWithValue(adviceGenerator),
        geminiApiKeyProvider.overrideWithValue(geminiApiKey),
        aiPreferencesStoreProvider.overrideWithValue(aiPrefs),
        localDataWiperProvider.overrideWithValue(wiper),
        connectivityMonitorProvider.overrideWithValue(connectivity),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 8, 12)),
        localTimeProvider.overrideWithValue(() => localNow),
        idGeneratorProvider.overrideWithValue(() => 'id-${idSeq++}'),
        // Signed-in as the placeholder user so uid-scoped providers resolve and
        // match the fake repos' seed data (Phase 5).
        currentUserIdProvider.overrideWithValue(kLocalUserId),
        if (signedInSession)
          sessionProvider.overrideWith(_ReadyLocalSession.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: home,
        builder: textScale == 1.0
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return TestRepos(
    container: ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ),
    transactions: txnRepo,
    categories: catRepo,
    budgets: budgetRepo,
    aggregates: aggRepo,
    preferences: prefs,
    maintenance: maintenance,
    gamification: gamificationRepo,
    adviceCache: adviceCache,
    adviceGenerator: adviceGenerator,
    connectivity: connectivity,
    aiPrefs: aiPrefs,
    wiper: wiper,
  );
}

/// A ready, signed-in session as the placeholder user — for `AuthGate` tests.
class _ReadyLocalSession extends SessionNotifier {
  @override
  Session build() =>
      const Session(uid: kLocalUserId, email: 'demo@example.com', ready: true);
}

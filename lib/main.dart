import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/dev/dev_seed.dart';
import 'data/local/hive_initializer.dart';
import 'presentation/providers/repository_providers.dart';
import 'presentation/screens/home_screen.dart';

/// Entry point.
///
/// Bootstraps encrypted local storage (Hive + AES key from the Keystore),
/// seeds the default categories on first launch, then hands off to the UI.
/// Everything from here runs fully offline.
Future<void> main() async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  final HiveStore store = await bootstrapHive();

  final container = ProviderContainer(
    overrides: [hiveStoreProvider.overrideWithValue(store)],
  );
  // First-launch seed of the default category set (Phase 1 task 7).
  await container.read(categoryRepositoryProvider).ensureDefaultsSeeded();

  // Debug-only: bulk transactions via --dart-define=DEV_SEED_TRANSACTIONS=<n>.
  final devSeeded = await maybeDevSeedTransactions(store);

  // Phase 4: build the PeriodAggregate cache for pre-existing Phase 2/3 data
  // (and for any dev-seeded rows, which bypass TransactionActions). Runs once,
  // guarded by a meta flag; the Settings "rebuild" action re-runs it on demand.
  final aggregatesBuilt =
      store.meta.get(MetaKeys.aggregatesBuilt, defaultValue: false) as bool;
  if (!aggregatesBuilt || devSeeded) {
    final txns = await container.read(transactionRepositoryProvider).getAll();
    await container.read(aggregationMaintenanceProvider).rebuildAll(txns);
    await store.meta.put(MetaKeys.aggregatesBuilt, true);
  }

  if (!kReleaseMode) {
    final bootMs = startupStopwatch.elapsedMilliseconds;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        'STARTUP: bootstrap=${bootMs}ms, '
        'firstFrame=${startupStopwatch.elapsedMilliseconds}ms, '
        'transactions=${store.transactions.length}',
      );
    });
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SpendlyApp()),
  );
}

class SpendlyApp extends StatelessWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

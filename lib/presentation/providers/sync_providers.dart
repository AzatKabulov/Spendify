import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_sync_metadata_store.dart';
import '../../data/remote/connectivity_plus_monitor.dart';
import '../../data/remote/firebase_bootstrap.dart';
import '../../data/remote/firestore_sync_gateway.dart';
import '../../data/repositories/sync_manager.dart';
import '../../domain/entities/sync_snapshot.dart';
import '../../domain/repositories/connectivity_monitor.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Connectivity monitor (real `connectivity_plus`). Overridable in tests.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => ConnectivityPlusMonitor(),
);

/// The Sync Manager — `null` when signed out or when Firebase was never
/// configured (`flutterfire configure` not run). Callers null-check; the app
/// works fully without it (CLAUDE.md §3).
///
/// Rebuilds when the signed-in user changes; the old instance is disposed.
final syncManagerProvider = Provider<SyncManager?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final firebaseReady =
      ref.watch(firebaseAvailabilityProvider) == FirebaseAvailability.ready;
  if (uid == null || !firebaseReady) return null;

  final store = ref.watch(hiveStoreProvider);
  final manager = SyncManager(
    gateway: FirestoreSyncGateway.instance(userId: uid),
    connectivity: ref.watch(connectivityMonitorProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    gamification: ref.watch(gamificationStateRepositoryProvider),
    aggregates: ref.watch(aggregationMaintenanceProvider),
    metadata: HiveSyncMetadataStore(store.meta),
    userId: uid,
    clock: ref.watch(clockProvider),
    // Local writes -> debounced upload. box.watch() fires on our own
    // markSynced writes too, but notifyLocalChange() no-ops mid-sync.
    changeStreams: <Stream<dynamic>>[
      store.transactions.watch(),
      store.categories.watch(),
      store.budgets.watch(),
      store.gamificationState.watch(),
    ],
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Live sync status for the indicator. Seeded with the manager's current
/// snapshot; a disabled snapshot when there is no manager.
final syncSnapshotProvider = StreamProvider<SyncSnapshot>((ref) {
  final manager = ref.watch(syncManagerProvider);
  if (manager == null) {
    return Stream<SyncSnapshot>.value(const SyncSnapshot());
  }
  return manager.changes;
});

/// `true` when sync is actually wired up (signed in + Firebase configured).
final syncAvailableProvider = Provider<bool>(
  (ref) => ref.watch(syncManagerProvider) != null,
);

/// Manual "Sync now" action for Settings.
final syncNowProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(syncManagerProvider)?.syncNow();
  };
});

/// Restore-on-first-launch + start/stop of background sync. Driven by the
/// session flow (`SessionNotifier.enter`) and `main()`.
final syncBootstrapProvider = Provider<SyncBootstrap>(SyncBootstrap.new);

class SyncBootstrap {
  SyncBootstrap(this._ref);

  final Ref _ref;

  /// A fresh install signing into an existing account: local data is empty and
  /// we have not restored before. A brand-new account also matches — the
  /// restore then pulls nothing, harmlessly.
  bool shouldRestore() {
    if (_ref.read(syncManagerProvider) == null) return false;
    final store = _ref.read(hiveStoreProvider);
    final alreadyRestored = HiveSyncMetadataStore(store.meta).restoreCompleted;
    return !alreadyRestored &&
        store.transactions.isEmpty &&
        store.budgets.isEmpty;
  }

  Future<void> restore({void Function(RestoreProgress)? onProgress}) async {
    final manager = _ref.read(syncManagerProvider);
    if (manager == null) return;
    try {
      await manager.restoreFromBackup(onProgress: onProgress);
    } catch (e) {
      if (!kReleaseMode) debugPrint('SYNC restore failed: $e');
      // Non-fatal — the background sync will keep trying.
    }
  }

  void startBackgroundSync() => _ref.read(syncManagerProvider)?.start();
}

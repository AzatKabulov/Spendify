import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import '../../core/clock.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/sync_snapshot.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/connectivity_monitor.dart';
import '../../domain/repositories/gamification_state_repository.dart';
import '../../domain/repositories/remote_sync_gateway.dart';
import '../../domain/repositories/sync_metadata_store.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/sync_policy.dart';
import '../remote/firestore_mappers.dart';
import 'aggregation_maintenance.dart';

/// Progress of a fresh-install restore, for the restore screen.
class RestoreProgress {
  const RestoreProgress({
    required this.collection,
    required this.done,
    required this.total,
  });
  final String collection;
  final int done;
  final int total;
}

/// Outcome of one [SyncManager.syncNow] attempt.
enum SyncOutcome {
  success,
  offline,
  retryableFailure,
  permanentFailure,
  skipped,
}

/// Local Hive <-> Firestore backup/restore (Phase 6).
///
/// **CLAUDE.md §3 non-negotiables baked in here:**
///  - Hive is the source of truth. This class only ever *reads* pending local
///    records and *writes back* `syncStatus` / remote copies — it is never on
///    the path of a UI read or a local write.
///  - Every trigger is fire-and-forget. A sync failure updates a snapshot and
///    schedules a retry; it never throws back to a caller that made a local
///    edit.
///
/// **What is NOT synced, deliberately:**
///  - `PeriodAggregate` — derived data. Rebuilt locally from transactions after
///    any pull ([AggregationMaintenance.rebuildAll]). Syncing it would double
///    write cost and invite drift.
///  - `AdviceRecord` — regenerable Gemini output, has no `updatedAt` / tombstone
///    (CLAUDE.md §4). One Gemini call after restore is cheaper than syncing it.
class SyncManager {
  SyncManager({
    required this.gateway,
    required this.connectivity,
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.gamification,
    required this.aggregates,
    required this.metadata,
    required this.userId,
    this.clock = systemClock,
    this.debounce = const Duration(seconds: 8),
    this.periodic = const Duration(minutes: 15),
    this.changeStreams = const <Stream<dynamic>>[],
  });

  final RemoteSyncGateway gateway;
  final ConnectivityMonitor connectivity;
  final TransactionRepository transactions;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final GamificationStateRepository gamification;
  final AggregationMaintenance aggregates;
  final SyncMetadataStore metadata;
  final String userId;
  final Clock clock;
  final Duration debounce;
  final Duration periodic;

  /// Hive `box.watch()` streams — a local write becomes a debounced upload.
  final List<Stream<dynamic>> changeStreams;

  final _snapshots = StreamController<SyncSnapshot>.broadcast();
  SyncSnapshot _snapshot = const SyncSnapshot();

  Future<SyncOutcome>? _inFlight;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _periodicTimer;
  int _retryAttempt = 0;
  final _subs = <StreamSubscription<dynamic>>[];
  bool _started = false;
  bool _disposed = false;

  SyncSnapshot get snapshot => _snapshot;
  Stream<SyncSnapshot> get changes => _snapshots.stream;

  // --- lifecycle ----------------------------------------------------

  /// Wire background triggers. Call once after sign-in / on a launch with a
  /// session. Idempotent.
  void start() {
    if (_started || _disposed) return;
    _started = true;

    _subs.add(
      connectivity.onlineChanges.listen((online) {
        _emit(
          _snapshot.copyWith(
            phase: online ? SyncPhase.idle : SyncPhase.offline,
          ),
        );
        if (online) _kick();
      }),
    );

    _periodicTimer = Timer.periodic(periodic, (_) => _kick());

    // Local box changes -> debounced upload. box.watch() also fires for our own
    // markSynced / upsertFromRemote writes, but [notifyLocalChange] no-ops
    // while a sync is in flight, so that never feeds back into a loop.
    for (final stream in changeStreams) {
      _subs.add(stream.listen((_) => notifyLocalChange()));
    }

    _kick(); // upload any pending backlog now
    unawaited(_refreshPendingCount());
  }

  /// Call from an app-resume lifecycle hook.
  void onAppResumed() => _kick();

  /// Debounced trigger after a local mutation.
  void notifyLocalChange() {
    if (_disposed || _inFlight != null) return;
    unawaited(_refreshPendingCount());
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _kick);
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _periodicTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _snapshots.close();
  }

  // --- public sync entry points ----------------------------------

  /// Full sync now (push, then pull, all collections). **Single-flight**: a
  /// call while one is running returns the *same* in-flight future — two syncs
  /// never run at once.
  Future<SyncOutcome> syncNow() =>
      _inFlight ??= _runOnce().whenComplete(() => _inFlight = null);

  /// Fresh-install restore: pull **everything** (no cursor), write locally with
  /// `syncStatus = synced`, rebuild aggregates. Reports progress. A no-op when
  /// there is nothing remote or no connectivity.
  Future<void> restoreFromBackup({
    void Function(RestoreProgress)? onProgress,
  }) async {
    if (!await connectivity.isOnline) return;
    _emit(_snapshot.copyWith(phase: SyncPhase.syncing, clearError: true));
    try {
      var pulledTransactions = 0;
      for (final col in SyncCollection.values) {
        onProgress?.call(
          RestoreProgress(collection: col.path, done: 0, total: 0),
        );
        final applied = await _pullCollection(col, since: null);
        if (col == SyncCollection.transactions) pulledTransactions = applied;
        onProgress?.call(
          RestoreProgress(collection: col.path, done: applied, total: applied),
        );
      }
      if (pulledTransactions > 0) await _rebuildAggregates();
      await metadata.markRestoreCompleted();
      final now = clock();
      await metadata.setLastSyncedAtMs(now.millisecondsSinceEpoch);
      _emit(
        _snapshot.copyWith(
          phase: SyncPhase.idle,
          lastSyncedAt: now,
          clearError: true,
        ),
      );
      await _refreshPendingCount();
    } on RemoteSyncException catch (e) {
      _emit(_snapshot.copyWith(phase: SyncPhase.error, lastError: e.message));
      rethrow;
    }
  }

  // --- internals --------------------------------------------------

  /// Trigger a sync unless one is running or a backoff retry is already queued.
  void _kick() {
    if (_disposed || _inFlight != null || _retryTimer != null) return;
    unawaited(syncNow());
  }

  Future<SyncOutcome> _runOnce() async {
    if (_disposed) return SyncOutcome.skipped;

    if (!await connectivity.isOnline) {
      _emit(_snapshot.copyWith(phase: SyncPhase.offline));
      return SyncOutcome.offline;
    }

    _emit(_snapshot.copyWith(phase: SyncPhase.syncing, clearError: true));
    try {
      // Push first so our latest local edits win a same-timestamp tie, then
      // pull to catch anything newer.
      await _pushAll();
      final appliedTxns = await _pullAll();
      if (appliedTxns > 0) await _rebuildAggregates();

      final now = clock();
      await metadata.setLastSyncedAtMs(now.millisecondsSinceEpoch);
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      await _refreshPendingCount();
      _emit(
        _snapshot.copyWith(
          phase: SyncPhase.idle,
          lastSyncedAt: now,
          clearError: true,
        ),
      );
      return SyncOutcome.success;
    } on PermanentSyncException catch (e, s) {
      _logError('permanent', e, s);
      _retryAttempt = 0; // do NOT loop on a permanent failure
      _emit(_snapshot.copyWith(phase: SyncPhase.error, lastError: e.message));
      return SyncOutcome.permanentFailure;
    } on RemoteSyncException catch (e, s) {
      _logError('retryable', e, s);
      _scheduleRetry();
      _emit(_snapshot.copyWith(phase: SyncPhase.error, lastError: e.message));
      return SyncOutcome.retryableFailure;
    } catch (e, s) {
      _logError('unexpected', e, s);
      _scheduleRetry();
      _emit(
        _snapshot.copyWith(
          phase: SyncPhase.error,
          lastError: 'Unexpected sync error',
        ),
      );
      return SyncOutcome.retryableFailure;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryAttempt++;
    _retryTimer = Timer(backoffDelay(_retryAttempt), () {
      _retryTimer = null;
      _kick();
    });
  }

  // --- push ------------------------------------------------------

  Future<void> _pushAll() async {
    await _pushSyncable(
      SyncCollection.transactions,
      transactions.getPendingSync,
      transactionToRemote,
      transactions.markSynced,
    );
    await _pushSyncable(
      SyncCollection.categories,
      categories.getPendingSync,
      categoryToRemote,
      categories.markSynced,
    );
    await _pushSyncable(
      SyncCollection.budgets,
      budgets.getPendingSync,
      budgetToRemote,
      budgets.markSynced,
    );
    await _pushGamification();
  }

  Future<void> _pushSyncable<E>(
    SyncCollection col,
    Future<List<E>> Function() pending,
    Map<String, Object?> Function(E) toRemote,
    Future<void> Function(String id) markSynced,
  ) async {
    final records = await pending();
    if (records.isEmpty) return;
    final docs = <RemoteDoc>[
      for (final r in records)
        RemoteDoc(id: toRemote(r)['id']! as String, data: toRemote(r)),
    ];
    await gateway.pushDocuments(col, docs);
    // Only after a fully successful upload — and via markSynced, which flips
    // syncStatus WITHOUT re-stamping updatedAt (else the record looks "newer"
    // on the next pull).
    for (final doc in docs) {
      await markSynced(doc.id);
    }
  }

  Future<void> _pushGamification() async {
    final state = await gamification.get();
    if (state == null || state.syncStatus != SyncStatus.pending) return;
    await gateway.pushDocuments(SyncCollection.gamification, <RemoteDoc>[
      RemoteDoc(id: userId, data: gamificationToRemote(state)),
    ]);
    await gamification.markSynced();
  }

  // --- pull -----------------------------------------------------

  Future<int> _pullAll() async {
    var appliedTransactions = 0;
    for (final col in SyncCollection.values) {
      final applied = await _pullCollection(col, since: _cursor(col));
      if (col == SyncCollection.transactions) appliedTransactions = applied;
    }
    return appliedTransactions;
  }

  Future<int> _pullCollection(
    SyncCollection col, {
    required DateTime? since,
  }) async {
    final remoteDocs = await gateway.pullDocuments(col, since: since);
    if (remoteDocs.isEmpty) return 0;

    var applied = 0;
    DateTime? maxUpdatedAt = since;
    for (final rd in remoteDocs) {
      if (await _applyRemote(col, rd)) applied++;
      final ru = rd.updatedAt;
      if (ru != null && (maxUpdatedAt == null || ru.isAfter(maxUpdatedAt))) {
        maxUpdatedAt = ru;
      }
    }
    if (maxUpdatedAt != null) await _setCursor(col, maxUpdatedAt);
    return applied;
  }

  /// LWW: write the remote copy only if it is strictly newer than local (or
  /// local is absent). Equal `updatedAt` -> keep local (deterministic).
  /// A tombstone (`isDeleted == true`) follows the same rule, so a deletion
  /// that already synced never resurrects on a restoring device.
  Future<bool> _applyRemote(SyncCollection col, RemoteDoc rd) async {
    switch (col) {
      case SyncCollection.transactions:
        final remote = transactionFromRemote(rd.data);
        final local = await transactions.getByIdIncludingDeleted(remote.id);
        if (local != null &&
            !remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            )) {
          return false;
        }
        await transactions.upsertFromRemote(remote);
        return true;
      case SyncCollection.categories:
        final remote = categoryFromRemote(rd.data);
        final local = await categories.getByIdIncludingDeleted(remote.id);
        if (local != null &&
            !remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            )) {
          return false;
        }
        await categories.upsertFromRemote(remote);
        return true;
      case SyncCollection.budgets:
        final remote = budgetFromRemote(rd.data);
        final local = await budgets.getByIdIncludingDeleted(remote.id);
        if (local != null &&
            !remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            )) {
          return false;
        }
        await budgets.upsertFromRemote(remote);
        return true;
      case SyncCollection.gamification:
        final remote = gamificationFromRemote(rd.data);
        final local = await gamification.get();
        if (local != null &&
            !remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            )) {
          return false;
        }
        await gamification.upsertFromRemote(remote);
        return true;
    }
  }

  Future<void> _rebuildAggregates() async {
    // reports + balances derive from these; keep them correct after a pull.
    await aggregates.rebuildAll(await transactions.getAll());
  }

  // --- cursors + snapshot -------------------------------------

  DateTime? _cursor(SyncCollection col) {
    final ms = metadata.readCursorMs(col.path);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> _setCursor(SyncCollection col, DateTime value) =>
      metadata.writeCursorMs(col.path, value.millisecondsSinceEpoch);

  Future<void> _refreshPendingCount() async {
    try {
      final t = await transactions.getPendingSync();
      final c = await categories.getPendingSync();
      final b = await budgets.getPendingSync();
      final g = await gamification.get();
      final gPending = g != null && g.syncStatus == SyncStatus.pending ? 1 : 0;
      _emit(
        _snapshot.copyWith(
          pendingCount: t.length + c.length + b.length + gPending,
        ),
      );
    } catch (_) {
      // pending count is cosmetic — never let it break anything
    }
  }

  void _emit(SyncSnapshot next) {
    _snapshot = next;
    if (!_snapshots.isClosed) _snapshots.add(next);
  }

  void _logError(String kind, Object error, StackTrace stack) {
    if (!kReleaseMode) debugPrint('SYNC ($kind): $error\n$stack');
  }
}

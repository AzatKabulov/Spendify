import 'dart:async';

import 'package:spendly/core/clock.dart';
import 'package:spendly/domain/entities/gamification_state.dart';
import 'package:spendly/domain/repositories/connectivity_monitor.dart';
import 'package:spendly/domain/repositories/gamification_state_repository.dart';
import 'package:spendly/domain/repositories/remote_sync_gateway.dart';
import 'package:spendly/domain/repositories/sync_metadata_store.dart';

/// In-memory [RemoteSyncGateway] — a fake "Firestore". Records every push and
/// serves pulls from its own store. Configurable to throw for failure tests.
class FakeRemoteSyncGateway implements RemoteSyncGateway {
  /// collection.path -> (docId -> data)
  final Map<String, Map<String, Map<String, Object?>>> store = {};

  final List<({SyncCollection collection, List<RemoteDoc> docs})> pushes = [];
  int pushCallCount = 0;
  int pullCallCount = 0;

  /// If set, the *next* push throws this then clears (one-shot).
  Object? throwOnNextPush;

  /// If set, every push throws this.
  Object? alwaysThrowOnPush;

  /// If set, [pushDocuments] awaits this before proceeding — lets a test hold a
  /// sync "in flight".
  Completer<void>? pushGate;

  @override
  Future<void> pushDocuments(
    SyncCollection collection,
    List<RemoteDoc> docs,
  ) async {
    pushCallCount++;
    pushes.add((collection: collection, docs: docs));
    if (pushGate != null) await pushGate!.future;
    if (alwaysThrowOnPush != null) throw alwaysThrowOnPush!;
    final oneShot = throwOnNextPush;
    if (oneShot != null) {
      throwOnNextPush = null;
      throw oneShot;
    }
    final col = store.putIfAbsent(collection.path, () => {});
    for (final d in docs) {
      col[d.id] = Map<String, Object?>.from(d.data);
    }
  }

  @override
  Future<List<RemoteDoc>> pullDocuments(
    SyncCollection collection, {
    DateTime? since,
  }) async {
    pullCallCount++;
    final col = store[collection.path] ?? const {};
    return <RemoteDoc>[
      for (final entry in col.entries)
        if (since == null || _after(entry.value['updatedAt'], since))
          RemoteDoc(
            id: entry.key,
            data: Map<String, Object?>.from(entry.value),
          ),
    ];
  }

  bool _after(Object? updatedAt, DateTime since) =>
      updatedAt is DateTime && updatedAt.isAfter(since);

  /// Seed a remote doc directly (simulates another device having uploaded).
  void seed(SyncCollection collection, String id, Map<String, Object?> data) {
    store.putIfAbsent(collection.path, () => {})[id] =
        Map<String, Object?>.from(data);
  }
}

/// Controllable connectivity for tests.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool startOnline = true}) : _online = startOnline;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  set online(bool value) {
    if (_online == value) return;
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  Future<void> close() => _controller.close();
}

/// In-memory [SyncMetadataStore] for tests.
class InMemorySyncMetadataStore implements SyncMetadataStore {
  final Map<String, int> _cursors = {};
  int? _lastSyncedAtMs;
  bool _restoreCompleted = false;

  @override
  int? readCursorMs(String collectionPath) => _cursors[collectionPath];

  @override
  Future<void> writeCursorMs(String collectionPath, int epochMs) async =>
      _cursors[collectionPath] = epochMs;

  @override
  int? get lastSyncedAtMs => _lastSyncedAtMs;

  @override
  Future<void> setLastSyncedAtMs(int epochMs) async =>
      _lastSyncedAtMs = epochMs;

  @override
  bool get restoreCompleted => _restoreCompleted;

  @override
  Future<void> markRestoreCompleted() async => _restoreCompleted = true;
}

/// In-memory [GamificationStateRepository] for tests.
class FakeGamificationStateRepository implements GamificationStateRepository {
  FakeGamificationStateRepository({String userId = 'u', Clock? clock})
    : _ownerId = userId,
      _clock = clock ?? systemClock;

  final String _ownerId;
  final Clock _clock;
  GamificationState? _state;
  final _controller = StreamController<GamificationState>.broadcast();

  @override
  Future<GamificationState?> get() async => _state;

  @override
  Future<GamificationState> getOrCreate() async =>
      _state ??= GamificationState.initial(userId: _ownerId, now: _clock());

  @override
  Stream<GamificationState> watch() => _controller.stream;

  @override
  Future<GamificationState> save(GamificationState state) async {
    _state = state.markUpdated(at: _clock());
    _controller.add(_state!);
    return _state!;
  }

  @override
  Future<void> upsertFromRemote(GamificationState state) async {
    _state = state;
    _controller.add(state);
  }

  @override
  Future<void> markSynced() async {
    final s = _state;
    if (s != null) _state = s.markSynced();
  }
}

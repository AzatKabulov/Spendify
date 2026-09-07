import '../entities/gamification_state.dart';

/// Storage contract for the single per-user [GamificationState] row.
///
/// Not a [SyncableRepository]: there is one row, keyed by userId, and it is
/// never deleted. It still syncs, so [save] stamps `updatedAt` and sets
/// `syncStatus = pending`.
abstract interface class GamificationStateRepository {
  /// The current user's state, creating a fresh zeroed row if none exists.
  Future<GamificationState> getOrCreate();

  /// The current user's state, or `null` if it has never been written.
  Future<GamificationState?> get();

  /// Emits the current state now and on every change.
  Stream<GamificationState> watch();

  /// Persist a mutated state. Stamps `updatedAt` + `syncStatus = pending`.
  Future<GamificationState> save(GamificationState state);

  // --- Sync Manager surface (Phase 6) -----------------------------------

  Future<void> upsertFromRemote(GamificationState state);

  Future<void> markSynced();
}

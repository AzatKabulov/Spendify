import '../entities/syncable.dart';

/// Local-first CRUD for a syncable aggregate (Transaction, Category, Budget).
///
/// Implementations live in `data/repositories/` and are the single place the
/// CLAUDE.md §8 rules are enforced:
///   - [delete] never removes a row — it sets `isDeleted = true`;
///   - [add] / [update] / [delete] stamp `updatedAt` and set
///     `syncStatus = pending`;
///   - [getAll] / [getById] / [watchAll] hide `isDeleted` rows.
///
/// The `*IncludingDeleted` / `*PendingSync` members are for the Phase 6 Sync
/// Manager, which must see tombstones.
abstract interface class SyncableRepository<E extends Syncable<E>> {
  /// All live (non-deleted) records for the current user.
  Future<List<E>> getAll();

  /// A single live record, or `null` if it is absent or soft-deleted.
  Future<E?> getById(String id);

  /// Emits the live record list now and again on every box change.
  Stream<List<E>> watchAll();

  /// Persist a new record. Returns the stored form (post-stamping).
  Future<E> add(E entity);

  /// Persist an edit to an existing record. Returns the stored form.
  Future<E> update(E entity);

  /// Soft-delete. No-op if the id is unknown.
  Future<void> delete(String id);

  /// Undo a soft-delete (the UI's UNDO action). No-op if the id is unknown or
  /// the record is not currently deleted.
  Future<void> restore(String id);

  // --- Sync Manager surface (Phase 6) -------------------------------------

  /// Records with `syncStatus == pending`, tombstones included.
  Future<List<E>> getPendingSync();

  /// A record by id even if soft-deleted; `null` only if truly absent.
  Future<E?> getByIdIncludingDeleted(String id);

  /// Write a record straight from remote during a pull, without re-stamping.
  Future<void> upsertFromRemote(E entity);

  /// Mark a record `syncStatus == synced` after a successful push.
  Future<void> markSynced(String id);
}

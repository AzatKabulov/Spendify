import 'enums.dart';

/// Contract for every record that syncs to Firestore later (Transaction,
/// Category, Budget). Carries the metadata from CLAUDE.md §4 and the three
/// mutation transforms from §8.
///
/// The transforms return a new instance (entities are immutable). Repositories
/// are the only callers — UI and services go through the repository, so the
/// "bump updatedAt + set syncStatus = pending on every mutation, soft-delete
/// only" rules cannot be skipped at a call site.
///
/// `T extends Syncable<T>` (F-bounded) so the transforms are typed to the
/// concrete entity, letting the generic repository base stay type-safe.
abstract interface class Syncable<T extends Syncable<T>> {
  String get id;
  String get userId;
  DateTime get createdAt;

  /// Drives last-write-wins conflict resolution. UTC.
  DateTime get updatedAt;

  /// Tombstone. Deleted rows are kept forever so the deletion can propagate.
  bool get isDeleted;

  SyncStatus get syncStatus;

  /// Local edit: `updatedAt = at`, `syncStatus = pending`.
  T markUpdated({required DateTime at});

  /// Soft delete: `isDeleted = true`, `updatedAt = at`, `syncStatus = pending`.
  T markDeleted({required DateTime at});

  /// Called by the Sync Manager (Phase 6) once the record matches remote.
  T markSynced();
}

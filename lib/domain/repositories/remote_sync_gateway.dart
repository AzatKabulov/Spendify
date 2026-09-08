/// The remote-backup boundary (Phase 6). The Firestore SDK is imported by
/// exactly one implementation (`data/remote/firestore_sync_gateway.dart`) so
/// the backend stays replaceable (CLAUDE.md §6). No Firestore type — `Timestamp`
/// included — leaks past this interface.
library;

/// A backup collection under `users/{uid}/`.
enum SyncCollection { transactions, categories, budgets, gamification }

extension SyncCollectionName on SyncCollection {
  /// Firestore sub-collection segment.
  String get path => switch (this) {
    SyncCollection.transactions => 'transactions',
    SyncCollection.categories => 'categories',
    SyncCollection.budgets => 'budgets',
    SyncCollection.gamification => 'gamification',
  };
}

/// One remote document as plain data. `data` is JSON-ish: `String`, `int`,
/// `double`, `bool`, `null`, `DateTime` (the gateway converts to/from
/// Firestore `Timestamp`), `List`, `Map`.
class RemoteDoc {
  const RemoteDoc({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;

  DateTime? get updatedAt {
    final v = data['updatedAt'];
    return v is DateTime ? v : null;
  }

  bool get isDeleted => data['isDeleted'] == true;
}

abstract interface class RemoteSyncGateway {
  /// Upload [docs] into [collection] under the signed-in user. Batched writes,
  /// chunked to Firestore's 500-operation limit. Soft-deleted records are
  /// uploaded as documents with `isDeleted == true` — this never calls a
  /// Firestore `delete()` (a missing doc is indistinguishable from one that
  /// was never created; a restoring device must see the tombstone).
  Future<void> pushDocuments(SyncCollection collection, List<RemoteDoc> docs);

  /// Remote docs in [collection] with `updatedAt` strictly after [since], or
  /// **all** docs when [since] is null (the fresh-install restore path).
  Future<List<RemoteDoc>> pullDocuments(
    SyncCollection collection, {
    DateTime? since,
  });
}

/// Raised by a [RemoteSyncGateway]. Split so the Sync Manager knows whether a
/// retry could ever succeed.
sealed class RemoteSyncException implements Exception {
  const RemoteSyncException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(${code ?? "?"}: $message)';
}

/// Transient — network down, timeout, server unavailable/aborted. Safe to
/// retry with backoff.
final class RetryableSyncException extends RemoteSyncException {
  const RetryableSyncException(super.message, {super.code, super.cause});
}

/// Will not succeed on retry — permission denied, malformed data, quota
/// exhausted, unauthenticated. Log and surface; do not loop.
final class PermanentSyncException extends RemoteSyncException {
  const PermanentSyncException(super.message, {super.code, super.cause});
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/remote_sync_gateway.dart';
import '../../domain/services/sync_policy.dart';

/// The **only** file that imports `cloud_firestore` (CLAUDE.md §6). Everything
/// above it works with plain [RemoteDoc]s and never sees a `Timestamp`,
/// `DocumentSnapshot`, or `FirebaseException`.
///
/// Firestore here is a backup target, not a data source — this class is only
/// ever driven by the Sync Manager in the background, never by the UI
/// (CLAUDE.md §3).
class FirestoreSyncGateway implements RemoteSyncGateway {
  FirestoreSyncGateway({
    required FirebaseFirestore firestore,
    required this.userId,
    this.timeout = const Duration(seconds: 30),
  }) : _db = firestore;

  /// Wire against `FirebaseFirestore.instance` — call only after
  /// `Firebase.initializeApp` has succeeded.
  factory FirestoreSyncGateway.instance({required String userId}) =>
      FirestoreSyncGateway(
        firestore: FirebaseFirestore.instance,
        userId: userId,
      );

  final FirebaseFirestore _db;
  final String userId;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> _collection(SyncCollection c) =>
      _db.collection('users').doc(userId).collection(c.path);

  @override
  Future<void> pushDocuments(
    SyncCollection collection,
    List<RemoteDoc> docs,
  ) async {
    if (docs.isEmpty) return;
    final ref = _collection(collection);

    // Chunk to Firestore's 500-operation write-batch limit.
    for (final chunk in chunkForBatch(docs, maxPerChunk: 500)) {
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.set(ref.doc(doc.id), <String, Object?>{
          ..._toFirestore(doc.data),
          // Server-side timestamp, for debugging clock skew only. LWW stays on
          // the device `updatedAt` so the same rule works offline.
          'serverSyncedAt': FieldValue.serverTimestamp(),
        });
      }
      await _guard(() => batch.commit(), 'push ${collection.path}');
    }
  }

  @override
  Future<List<RemoteDoc>> pullDocuments(
    SyncCollection collection, {
    DateTime? since,
  }) async {
    Query<Map<String, dynamic>> query = _collection(collection);
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(since),
      );
    }
    final snap = await _guard(() => query.get(), 'pull ${collection.path}');
    return <RemoteDoc>[
      for (final doc in snap.docs)
        RemoteDoc(id: doc.id, data: _fromFirestore(doc.data())),
    ];
  }

  Future<T> _guard<T>(Future<T> Function() op, String what) async {
    try {
      return await op().timeout(timeout);
    } on FirebaseException catch (e) {
      throw classifyFirestoreError(e.code, e.message, what: what, cause: e);
    } on TimeoutException catch (e) {
      throw RetryableSyncException(
        '$what timed out',
        code: 'timeout',
        cause: e,
      );
    }
  }

  /// `DateTime` -> Firestore `Timestamp` for every time field.
  Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
      <String, Object?>{
        for (final entry in data.entries)
          entry.key: entry.value is DateTime
              ? Timestamp.fromDate(entry.value! as DateTime)
              : entry.value,
      };

  /// Firestore `Timestamp` -> `DateTime`; drops the debug-only server field.
  Map<String, Object?> _fromFirestore(Map<String, dynamic> data) =>
      <String, Object?>{
        for (final entry in data.entries)
          if (entry.key != 'serverSyncedAt')
            entry.key: entry.value is Timestamp
                ? (entry.value as Timestamp).toDate()
                : entry.value,
      };
}

/// Maps a Firestore error `code` to the retryable / permanent split the Sync
/// Manager needs. Pure (`String -> RemoteSyncException`), so it is unit-testable
/// without a live Firestore.
///
///  - **Retryable** (`unavailable`, `deadline-exceeded`, `aborted`, network):
///    a backoff retry can succeed.
///  - **Permanent** (`permission-denied`, `invalid-argument`, `resource-
///    exhausted`/quota, malformed data): retrying in a loop only makes it
///    worse — surface it, let the periodic timer try again later.
RemoteSyncException classifyFirestoreError(
  String code,
  String? message, {
  String? what,
  Object? cause,
}) {
  final msg = '${message ?? code}${what == null ? "" : " ($what)"}';
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
    case 'aborted':
    case 'cancelled':
    case 'internal':
    case 'timeout':
      return RetryableSyncException(msg, code: code, cause: cause);
    case 'permission-denied':
    case 'unauthenticated':
    case 'invalid-argument':
    case 'not-found':
    case 'already-exists':
    case 'failed-precondition':
    case 'out-of-range':
    case 'unimplemented':
    case 'data-loss':
    case 'resource-exhausted': // quota — retrying just burns more of it
      return PermanentSyncException(msg, code: code, cause: cause);
    default:
      // Unknown code: retryable so a transient blip isn't fatal, but bounded
      // by the backoff cap + the surfaced error.
      return RetryableSyncException(msg, code: code, cause: cause);
  }
}

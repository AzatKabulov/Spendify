import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../domain/repositories/sync_metadata_store.dart';

/// [SyncMetadataStore] backed by the encrypted Hive meta box.
class HiveSyncMetadataStore implements SyncMetadataStore {
  HiveSyncMetadataStore(this._meta);

  final Box<dynamic> _meta;

  @override
  int? readCursorMs(String collectionPath) {
    final v = _meta.get(MetaKeys.syncCursor(collectionPath));
    return v is int ? v : null;
  }

  @override
  Future<void> writeCursorMs(String collectionPath, int epochMs) =>
      _meta.put(MetaKeys.syncCursor(collectionPath), epochMs);

  @override
  int? get lastSyncedAtMs {
    final v = _meta.get(MetaKeys.lastSyncedAt);
    return v is int ? v : null;
  }

  @override
  Future<void> setLastSyncedAtMs(int epochMs) =>
      _meta.put(MetaKeys.lastSyncedAt, epochMs);

  @override
  bool get restoreCompleted => _meta.get(MetaKeys.restoreCompleted) == true;

  @override
  Future<void> markRestoreCompleted() =>
      _meta.put(MetaKeys.restoreCompleted, true);
}

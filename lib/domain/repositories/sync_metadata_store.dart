/// Small persisted key/value the Sync Manager needs between runs: the
/// per-collection pull cursor, the last successful sync time, and the
/// restore-done flag. Backed by the Hive meta box in the app; an in-memory map
/// in tests. Keeps `sync_manager.dart` free of a Hive import.
library;

abstract interface class SyncMetadataStore {
  /// Max remote `updatedAt` (epoch ms) applied so far for [collectionPath], or
  /// `null` if this collection has never been pulled.
  int? readCursorMs(String collectionPath);

  Future<void> writeCursorMs(String collectionPath, int epochMs);

  /// Epoch ms of the last fully successful sync, or `null`.
  int? get lastSyncedAtMs;

  Future<void> setLastSyncedAtMs(int epochMs);

  /// Whether a fresh-install restore has already completed on this device.
  bool get restoreCompleted;

  Future<void> markRestoreCompleted();
}

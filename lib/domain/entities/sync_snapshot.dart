/// What the Sync Manager is doing right now — for the small status indicator
/// (CLAUDE.md §3: the UI observes sync, it never depends on it).
library;

enum SyncPhase {
  /// Nothing to do; everything local is backed up.
  idle,

  /// A push/pull is running.
  syncing,

  /// No connectivity — sync is paused, local writes are unaffected.
  offline,

  /// The last attempt failed. [SyncSnapshot.lastError] has the reason.
  error,
}

class SyncSnapshot {
  const SyncSnapshot({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.lastError,
  });

  final SyncPhase phase;

  /// When the last **successful** full sync finished. `null` = never.
  final DateTime? lastSyncedAt;

  /// Local records still waiting to upload.
  final int pendingCount;

  /// Human-readable reason for [SyncPhase.error]; `null` otherwise.
  final String? lastError;

  bool get isSyncing => phase == SyncPhase.syncing;
  bool get hasError => phase == SyncPhase.error;

  SyncSnapshot copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    int? pendingCount,
    String? lastError,
    bool clearError = false,
  }) => SyncSnapshot(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    pendingCount: pendingCount ?? this.pendingCount,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  String toString() =>
      'SyncSnapshot(${phase.name}, pending=$pendingCount, '
      'lastSyncedAt=$lastSyncedAt${lastError == null ? "" : ", err=$lastError"})';
}

import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../domain/entities/enums.dart';
import 'hive_initializer.dart';

/// Result of one [UserIdMigration.run] pass.
class UserIdMigrationResult {
  const UserIdMigrationResult({
    required this.rewritten,
    required this.complete,
  });

  /// How many records were re-keyed this pass (0 when already done).
  final int rewritten;

  /// `true` once a full pass leaves **zero** placeholder records — the
  /// [MetaKeys.userIdMigratedTo] flag is written only then.
  final bool complete;

  @override
  String toString() =>
      'UserIdMigrationResult(rewritten: $rewritten, complete: $complete)';
}

/// One-shot, irreversible re-keying of the Phase 1 placeholder [kLocalUserId] to
/// the real Firebase UID across every local box (CLAUDE.md §4.1).
///
/// Properties (Phase 5 brief, Part C):
///  - **Idempotent** — running again after completion is a guarded no-op; even
///    unguarded, a second pass finds nothing to do.
///  - **Resumable** — there is no "in progress" flag. Each pass rewrites
///    whatever placeholder records remain and `box.put`s them one at a time
///    (each put is atomic). If the process dies mid-pass, the next launch's
///    pass finishes the job. The completion flag is written only after a pass
///    verifies nothing placeholder-owned is left.
///  - **Sync-ready** — every rewritten syncable record gets `updatedAt = now`
///    and `syncStatus = pending` so Phase 6 uploads it under the real UID.
class UserIdMigration {
  UserIdMigration(this._store, {this.clock = systemClock});

  final HiveStore _store;
  final Clock clock;

  /// Re-key everything owned by [kLocalUserId] to [realUid].
  Future<UserIdMigrationResult> run({required String realUid}) async {
    if (realUid.isEmpty || realUid == kLocalUserId) {
      throw ArgumentError.value(
        realUid,
        'realUid',
        'must be a real Firebase UID, not the placeholder',
      );
    }

    final recorded = _store.meta.get(MetaKeys.userIdMigratedTo);
    if (recorded == realUid) {
      return const UserIdMigrationResult(rewritten: 0, complete: true);
    }
    if (recorded is String && recorded.isNotEmpty && recorded != realUid) {
      // A different account already owns this device's data. Phase 5 is
      // single-user; re-keying would silently hand one user's data to another.
      throw StateError(
        'Local data is already migrated to "$recorded"; refusing to re-key to '
        '"$realUid". A second account on the same device is a Phase 6+ concern.',
      );
    }

    final now = clock();
    var rewritten = 0;

    // --- Syncable boxes: id-keyed, carry updatedAt + syncStatus -------------
    for (final m in _store.transactions.values.toList(growable: false)) {
      if (m.userId != kLocalUserId) continue;
      m.userId = realUid;
      m.updatedAt = now;
      m.syncStatus = SyncStatus.pending;
      await _store.transactions.put(m.id, m);
      rewritten++;
    }
    for (final m in _store.categories.values.toList(growable: false)) {
      if (m.userId != kLocalUserId) continue;
      m.userId = realUid;
      m.updatedAt = now;
      m.syncStatus = SyncStatus.pending;
      await _store.categories.put(m.id, m);
      rewritten++;
    }
    for (final m in _store.budgets.values.toList(growable: false)) {
      if (m.userId != kLocalUserId) continue;
      m.userId = realUid;
      m.updatedAt = now;
      m.syncStatus = SyncStatus.pending;
      await _store.budgets.put(m.id, m);
      rewritten++;
    }

    // --- AdviceRecord: id-keyed, no sync metadata (local cache) -------------
    for (final m in _store.adviceRecords.values.toList(growable: false)) {
      if (m.userId != kLocalUserId) continue;
      m.userId = realUid;
      await _store.adviceRecords.put(m.id, m);
      rewritten++;
    }

    // --- GamificationState: one row, keyed BY userId -> re-key the entry ----
    final gs = _store.gamificationState.get(kLocalUserId);
    if (gs != null) {
      gs.userId = realUid;
      gs.updatedAt = now;
      gs.syncStatus = SyncStatus.pending;
      await _store.gamificationState.put(realUid, gs);
      await _store.gamificationState.delete(kLocalUserId);
      rewritten++;
    }

    // --- PeriodAggregate: composite id embeds userId. Cheapest correct move
    //     is to drop the cache and let main()'s rebuild repopulate it under the
    //     real UID (it is "rebuilt, never synced" — CLAUDE.md §6).
    if (_store.periodAggregates.isNotEmpty) {
      await _store.periodAggregates.clear();
      await _store.meta.delete(MetaKeys.aggregatesBuilt);
      if (!kReleaseMode) {
        debugPrint('MIGRATION: cleared PeriodAggregate cache for rebuild');
      }
    }

    final complete = !_placeholdersRemain();
    if (complete) {
      await _store.meta.put(MetaKeys.userIdMigratedTo, realUid);
    } else if (!kReleaseMode) {
      debugPrint(
        'MIGRATION: placeholder records still present after a pass — will '
        'retry on next launch',
      );
    }

    if (!kReleaseMode) {
      debugPrint('MIGRATION: rewrote $rewritten record(s), complete=$complete');
    }
    return UserIdMigrationResult(rewritten: rewritten, complete: complete);
  }

  /// `true` if the completion flag says this device is fully migrated.
  bool isComplete({required String realUid}) =>
      _store.meta.get(MetaKeys.userIdMigratedTo) == realUid;

  bool _placeholdersRemain() {
    bool any(Iterable<String> userIds) => userIds.any((u) => u == kLocalUserId);
    return any(_store.transactions.values.map((m) => m.userId)) ||
        any(_store.categories.values.map((m) => m.userId)) ||
        any(_store.budgets.values.map((m) => m.userId)) ||
        any(_store.adviceRecords.values.map((m) => m.userId)) ||
        any(_store.gamificationState.values.map((m) => m.userId));
  }
}

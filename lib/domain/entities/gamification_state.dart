import 'enums.dart';
import 'patch.dart';

/// One row per user. Not a [Syncable] — it has no `id`/`createdAt`/`isDeleted`
/// (CLAUDE.md §4): the primary key is [userId], and it is never deleted, only
/// updated. Still syncs, so it carries [updatedAt] + [syncStatus].
///
/// Phase 1 only defines and persists it. The award rules that mutate it are
/// the pure `GamificationEngine` in Phase 8.
class GamificationState {
  const GamificationState({
    required this.userId,
    required this.updatedAt,
    this.xp = 0,
    this.coins = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.unlockedBadgeIds = const <String>[],
    this.syncStatus = SyncStatus.pending,
  });

  /// A fresh state for a user who has earned nothing yet.
  factory GamificationState.initial({
    required String userId,
    required DateTime now,
  }) => GamificationState(userId: userId, updatedAt: now);

  final String userId;
  final int xp;
  final int coins;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final List<String> unlockedBadgeIds;

  final DateTime updatedAt;
  final SyncStatus syncStatus;

  GamificationState copyWith({
    int? xp,
    int? coins,
    int? level,
    int? currentStreak,
    int? longestStreak,
    Patch<DateTime?>? lastActivityDate,
    List<String>? unlockedBadgeIds,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return GamificationState(
      userId: userId,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: resolvePatch(lastActivityDate, this.lastActivityDate),
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  GamificationState markUpdated({required DateTime at}) =>
      copyWith(updatedAt: at, syncStatus: SyncStatus.pending);

  GamificationState markSynced() => copyWith(syncStatus: SyncStatus.synced);

  @override
  bool operator ==(Object other) =>
      other is GamificationState &&
      other.userId == userId &&
      other.xp == xp &&
      other.coins == coins &&
      other.level == level &&
      other.currentStreak == currentStreak &&
      other.longestStreak == longestStreak &&
      other.lastActivityDate == lastActivityDate &&
      _listEquals(other.unlockedBadgeIds, unlockedBadgeIds) &&
      other.updatedAt == updatedAt &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
    userId,
    xp,
    coins,
    level,
    currentStreak,
    longestStreak,
    lastActivityDate,
    Object.hashAll(unlockedBadgeIds),
    updatedAt,
    syncStatus,
  );

  @override
  String toString() =>
      'GamificationState($userId, xp=$xp, coins=$coins, lvl=$level, '
      'streak=$currentStreak/$longestStreak, badges=${unlockedBadgeIds.length})';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

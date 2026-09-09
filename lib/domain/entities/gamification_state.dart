import 'enums.dart';
import 'patch.dart';

/// One row per user. Not a [Syncable] — it has no `id`/`createdAt`/`isDeleted`
/// (CLAUDE.md §4): the primary key is [userId], and it is never deleted, only
/// updated. Still syncs, so it carries [updatedAt] + [syncStatus].
///
/// Phase 8 added the lifetime counters + [recentEventIds] so every badge
/// criterion is checkable from this object alone (the engine never reaches into
/// a repository). This is a deliberate, flagged extension of the CLAUDE.md §4
/// field list.
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
    this.transactionsLogged = 0,
    this.budgetsCreated = 0,
    this.budgetPeriodsWithinLimit = 0,
    this.scannedTransactionsLogged = 0,
    this.recentEventIds = const <String>[],
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

  /// Consecutive calendar days with at least one transaction logged. Resets to
  /// 1 (not 0) after a missed day. Local calendar days (Phase 8 / CLAUDE.md §9).
  final int currentStreak;

  /// High-water mark for [currentStreak]. **Never decreases.**
  final int longestStreak;

  /// The calendar day (date-only) of the most recent day a transaction was
  /// logged — the streak anchor. `null` until the first log.
  final DateTime? lastActivityDate;

  final List<String> unlockedBadgeIds;

  /// Lifetime count of transactions logged (never decremented — "you logged
  /// 100 transactions" stays true even after deletes). Drives the count badges.
  final int transactionsLogged;

  /// Lifetime count of budgets created.
  final int budgetsCreated;

  /// Lifetime count of budget periods that finished within their limit.
  final int budgetPeriodsWithinLimit;

  /// Lifetime count of transactions logged from a receipt scan.
  final int scannedTransactionsLogged;

  /// Bounded (most-recent-first, capped) list of processed gamification event
  /// ids — the idempotency guard and the XP-reversal window. Small enough to
  /// sync.
  final List<String> recentEventIds;

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
    int? transactionsLogged,
    int? budgetsCreated,
    int? budgetPeriodsWithinLimit,
    int? scannedTransactionsLogged,
    List<String>? recentEventIds,
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
      transactionsLogged: transactionsLogged ?? this.transactionsLogged,
      budgetsCreated: budgetsCreated ?? this.budgetsCreated,
      budgetPeriodsWithinLimit:
          budgetPeriodsWithinLimit ?? this.budgetPeriodsWithinLimit,
      scannedTransactionsLogged:
          scannedTransactionsLogged ?? this.scannedTransactionsLogged,
      recentEventIds: recentEventIds ?? this.recentEventIds,
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
      other.transactionsLogged == transactionsLogged &&
      other.budgetsCreated == budgetsCreated &&
      other.budgetPeriodsWithinLimit == budgetPeriodsWithinLimit &&
      other.scannedTransactionsLogged == scannedTransactionsLogged &&
      _listEquals(other.recentEventIds, recentEventIds) &&
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
    transactionsLogged,
    budgetsCreated,
    budgetPeriodsWithinLimit,
    scannedTransactionsLogged,
    Object.hashAll(recentEventIds),
    updatedAt,
    syncStatus,
  );

  @override
  String toString() =>
      'GamificationState($userId, xp=$xp, coins=$coins, lvl=$level, '
      'streak=$currentStreak/$longestStreak, badges=${unlockedBadgeIds.length}, '
      'logged=$transactionsLogged)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

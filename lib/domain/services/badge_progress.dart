/// Progress towards each badge, for the achievements list. Pure.
///
/// **Kept deliberately next to `badge_rules.dart`:** the thresholds here must
/// match the ones that actually unlock a badge there. A mismatch would show a
/// full progress bar on a locked badge (or vice versa), so the two files are
/// edited together — `badge_progress_test.dart` asserts they agree.
library;

import '../entities/badge_catalogue.dart';
import '../entities/gamification_state.dart';

/// How far [state] has come towards a badge: [current] out of [target].
///
/// [target] is 0 for badges that have no countable progress (the
/// "use every category" one), which are simply locked or unlocked.
class BadgeProgress {
  const BadgeProgress({
    required this.current,
    required this.target,
    required this.unlocked,
  });

  final int current;
  final int target;
  final bool unlocked;

  bool get isCountable => target > 0;

  /// 1.0 once unlocked, so a held badge never shows a part-full bar even if
  /// the underlying counter was later reduced (a deletion can lower XP).
  double get fraction {
    if (unlocked) return 1;
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }

  /// `true` when the user has started but not finished — drives the
  /// "In progress" filter.
  bool get inProgress => !unlocked && current > 0;
}

/// Progress towards [badgeId] given [state]. Unknown ids come back locked
/// with no countable target.
BadgeProgress badgeProgressFor(GamificationState state, String badgeId) {
  final unlocked = state.unlockedBadgeIds.contains(badgeId);
  final (current, target) = switch (badgeId) {
    'first_transaction' => (state.transactionsLogged, 1),
    'transactions_10' => (state.transactionsLogged, 10),
    'transactions_50' => (state.transactionsLogged, 50),
    'transactions_100' => (state.transactionsLogged, 100),
    'first_budget' => (state.budgetsCreated, 1),
    'budget_kept' => (state.budgetPeriodsWithinLimit, 1),
    'streak_3' => (state.longestStreak, 3),
    'streak_7' => (state.longestStreak, 7),
    'streak_30' => (state.longestStreak, 30),
    'first_scan' => (state.scannedTransactionsLogged, 1),
    'level_5' => (state.level, 5),
    'level_10' => (state.level, 10),
    // 'all_categories' is evaluated from the event, not a counter.
    _ => (0, 0),
  };
  return BadgeProgress(
    current: current > target && target > 0 ? target : current,
    target: target,
    unlocked: unlocked,
  );
}

/// The groups the achievements screen filters by. Derived from the badge ids
/// rather than stored on [Badge] — it is a presentation grouping, not data.
enum BadgeGroup { logging, streaks, budgeting, scanning, levels }

extension BadgeGroupLabel on BadgeGroup {
  String get label => switch (this) {
    BadgeGroup.logging => 'Logging',
    BadgeGroup.streaks => 'Streaks',
    BadgeGroup.budgeting => 'Budgeting',
    BadgeGroup.scanning => 'Scanning',
    BadgeGroup.levels => 'Levels',
  };
}

BadgeGroup badgeGroupFor(String badgeId) {
  if (badgeId.startsWith('streak_')) return BadgeGroup.streaks;
  if (badgeId.startsWith('level_')) return BadgeGroup.levels;
  if (badgeId.contains('budget')) return BadgeGroup.budgeting;
  if (badgeId.contains('scan')) return BadgeGroup.scanning;
  return BadgeGroup.logging;
}

/// Every badge id in the catalogue, for exhaustiveness checks in tests.
List<String> get allBadgeIds => <String>[
  for (final badge in kBadgeCatalogue) badge.id,
];

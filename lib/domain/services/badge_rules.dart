/// Badge unlock rules — pure. Every criterion is checkable from
/// `GamificationState` (already updated for the current event) plus the event
/// itself. Unlocks are permanent: this returns only badges **not yet held**,
/// and nothing ever removes one.
library;

import '../entities/gamification_state.dart';
import 'gamification_engine.dart';

/// Badge ids newly unlocked by reaching [state] (post-award) with [event].
List<String> badgesUnlockedBy(
  GamificationState state,
  GamificationEvent event,
) {
  final unlocked = <String>[];
  void award(String id, bool earned) {
    if (earned && !state.unlockedBadgeIds.contains(id)) unlocked.add(id);
  }

  award('first_transaction', state.transactionsLogged >= 1);
  award('transactions_10', state.transactionsLogged >= 10);
  award('transactions_50', state.transactionsLogged >= 50);
  award('transactions_100', state.transactionsLogged >= 100);

  award('first_budget', state.budgetsCreated >= 1);
  award('budget_kept', state.budgetPeriodsWithinLimit >= 1);

  // Streak badges check `longestStreak` (never decreases) so a badge earned at
  // a 7-day streak stays even after the streak later breaks.
  award('streak_3', state.longestStreak >= 3);
  award('streak_7', state.longestStreak >= 7);
  award('streak_30', state.longestStreak >= 30);

  award('first_scan', state.scannedTransactionsLogged >= 1);
  award(
    'all_categories',
    event is TransactionLogged && event.allCategoriesUsed,
  );

  award('level_5', state.level >= 5);
  award('level_10', state.level >= 10);

  return unlocked;
}

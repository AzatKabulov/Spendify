/// Where the app layers hand gamification events (Phase 8, Part F). The
/// Transaction and Budget action classes call the first three; the launch/resume
/// budget-period reconciler calls the last one.
///
/// **Fire-and-forget.** Every method returns `void`: the implementation queues
/// the event and runs the pure `GamificationEngine` + persistence in the
/// background, so gamification never sits on the critical path of adding a
/// transaction (CLAUDE.md §3 / §6, the 2-second bar). The caller's own write has
/// already succeeded before it calls here.
///
/// A `null` sink (a test, or any not-yet-signed-in context) means "gamification
/// off" — the action still completes.
library;

import '../entities/budget.dart';
import '../entities/enums.dart';
import '../entities/transaction.dart';

abstract interface class GamificationEventSink {
  /// A transaction was created (manual or scanned), or an undo re-added one.
  void transactionLogged(Transaction txn);

  /// A live transaction was soft-deleted (reverses its logging award only).
  void transactionDeleted(Transaction txn);

  /// A budget was created.
  void budgetCreated(Budget budget);

  /// A budget period that has now ended is being reconciled — [stayedWithinLimit]
  /// is spend ≤ limit for that finished period, from the cached aggregate. Safe
  /// to call every launch: the engine dedupes on `(budgetId, periodKey)`.
  void budgetPeriodCompleted({
    required String budgetId,
    required String periodKey,
    required BudgetPeriod period,
    required bool stayedWithinLimit,
  });
}

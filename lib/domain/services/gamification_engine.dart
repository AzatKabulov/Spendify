/// The Gamification Engine — **pure logic** (CLAUDE.md §5). No Hive, no
/// Firebase, no Flutter, no `DateTime.now()`: `process` takes the current
/// state + an event and returns what changed. A listener in the presentation
/// layer feeds it events and persists the result; the engine never touches a
/// repository or a widget.
///
/// **Ethics (CLAUDE.md §7):** every award is for a budgeting action — logging,
/// staying within a limit, day-over-day consistency. Nothing rewards app opens,
/// session length, or screen views.
library;

import '../entities/enums.dart';
import '../entities/gamification_state.dart';
import '../entities/patch.dart';
import 'badge_rules.dart';
import 'gamification_rules.dart';

// --- events ------------------------------------------------------------

/// Something the Transaction or Budget layer did that gamification cares about.
/// [id] is a deterministic idempotency key — processing the same event twice
/// awards once.
sealed class GamificationEvent {
  const GamificationEvent({required this.id, required this.occurredAt});

  /// Idempotency key. Deterministic from the underlying record so a re-fire
  /// (retry, or Phase 2 undo re-adding a row) is recognised.
  final String id;

  /// Wall-clock time the action happened — the streak's calendar-day source.
  final DateTime occurredAt;
}

/// A transaction was logged (manual or scanned).
class TransactionLogged extends GamificationEvent {
  TransactionLogged({
    required this.transactionId,
    required this.source,
    required DateTime loggedAt,
    this.allCategoriesUsed = false,
  }) : super(id: 'log:$transactionId', occurredAt: loggedAt);

  final String transactionId;
  final TransactionSource source;

  /// Listener-computed: every non-deleted category now has ≥ 1 transaction.
  final bool allCategoriesUsed;
}

/// A transaction was soft-deleted. Reverses the *logging* XP/coins only — never
/// the streak, `longestStreak`, or any badge (CLAUDE.md-style: taking away an
/// earned thing feels punitive).
class TransactionDeleted extends GamificationEvent {
  TransactionDeleted({required this.transactionId, required DateTime deletedAt})
    : super(id: 'del:$transactionId', occurredAt: deletedAt);

  final String transactionId;
}

/// A budget was created.
class BudgetCreated extends GamificationEvent {
  BudgetCreated({required this.budgetId, required DateTime createdAt})
    : super(id: 'bc:$budgetId', occurredAt: createdAt);

  final String budgetId;
}

/// A budget period finished (detected by the reconciler when the app is
/// opened after a period boundary).
class BudgetPeriodCompleted extends GamificationEvent {
  BudgetPeriodCompleted({
    required this.budgetId,
    required this.periodKey,
    required this.period,
    required this.stayedWithinLimit,
    required DateTime completedAt,
  }) : super(id: 'bp:$budgetId:$periodKey', occurredAt: completedAt);

  final String budgetId;
  final String periodKey;
  final BudgetPeriod period;
  final bool stayedWithinLimit;
}

/// First transaction of a new calendar day. The engine also derives this from
/// [TransactionLogged], so the wiring does not currently raise it separately —
/// it exists so the streak reward can be triggered independently later.
class DailyFirstLog extends GamificationEvent {
  DailyFirstLog({required String key, required DateTime at})
    : super(id: 'day:$key', occurredAt: at);
}

// --- result ----------------------------------------------------------

class GamificationResult {
  const GamificationResult({
    required this.state,
    this.xpAwarded = 0,
    this.coinsAwarded = 0,
    this.newlyUnlockedBadgeIds = const <String>[],
    this.streakBefore = 0,
    this.streakAfter = 0,
    this.leveledUp = false,
    this.newLevel = 1,
  });

  /// The state to persist.
  final GamificationState state;

  /// XP change from *this* event (negative on a reversal).
  final int xpAwarded;
  final int coinsAwarded;
  final List<String> newlyUnlockedBadgeIds;
  final int streakBefore;
  final int streakAfter;
  final bool leveledUp;
  final int newLevel;

  /// `true` when the event changed nothing (an idempotent duplicate, or a
  /// delete of a transaction that was never awarded).
  bool get isNoop =>
      xpAwarded == 0 &&
      coinsAwarded == 0 &&
      newlyUnlockedBadgeIds.isEmpty &&
      streakBefore == streakAfter;

  bool get hasVisibleReward =>
      xpAwarded > 0 || coinsAwarded > 0 || newlyUnlockedBadgeIds.isNotEmpty;
}

// --- engine ---------------------------------------------------------

class GamificationEngine {
  const GamificationEngine();

  GamificationResult process(GamificationEvent event, GamificationState state) {
    // Idempotency: this exact event already applied.
    if (state.recentEventIds.contains(event.id)) {
      return GamificationResult(
        state: state,
        streakBefore: state.currentStreak,
        streakAfter: state.currentStreak,
        newLevel: state.level,
      );
    }

    return switch (event) {
      TransactionLogged() => _transactionLogged(event, state),
      TransactionDeleted() => _transactionDeleted(event, state),
      BudgetCreated() => _budgetCreated(event, state),
      BudgetPeriodCompleted() => _budgetPeriodCompleted(event, state),
      DailyFirstLog() => _dailyFirstLog(event, state),
    };
  }

  GamificationResult _transactionLogged(
    TransactionLogged e,
    GamificationState state,
  ) {
    final streak = _rollStreak(state, e.occurredAt);
    final xp = state.xp + kXpPerTransactionLogged + streak.xpBonus;
    final coins = state.coins + kCoinsPerTransactionLogged + streak.coinBonus;

    var next = state.copyWith(
      xp: xp,
      coins: coins,
      level: levelForXp(xp),
      currentStreak: streak.streak,
      longestStreak: streak.longest,
      lastActivityDate: Patch<DateTime?>(streak.day),
      transactionsLogged: state.transactionsLogged + 1,
      scannedTransactionsLogged:
          state.scannedTransactionsLogged +
          (e.source == TransactionSource.scanned ? 1 : 0),
    );

    final unlocked = badgesUnlockedBy(next, e);
    next = next.copyWith(
      unlockedBadgeIds: <String>[...next.unlockedBadgeIds, ...unlocked],
      recentEventIds: _pushEvent(next.recentEventIds, e.id),
    );

    return GamificationResult(
      state: next,
      xpAwarded: next.xp - state.xp,
      coinsAwarded: next.coins - state.coins,
      newlyUnlockedBadgeIds: unlocked,
      streakBefore: state.currentStreak,
      streakAfter: next.currentStreak,
      leveledUp: next.level > state.level,
      newLevel: next.level,
    );
  }

  GamificationResult _transactionDeleted(
    TransactionDeleted e,
    GamificationState state,
  ) {
    // Only reverse if we actually awarded this transaction's logging.
    final wasAwarded = state.recentEventIds.contains('log:${e.transactionId}');
    if (!wasAwarded) {
      return GamificationResult(
        state: state,
        streakBefore: state.currentStreak,
        streakAfter: state.currentStreak,
        newLevel: state.level,
      );
    }

    // Reverse the per-transaction logging award only. NOT the daily bonus (a
    // day's consistency reward, not tied to one row), NOT the streak, NOT any
    // badge, NOT `transactionsLogged` ("you logged N" stays true). XP floors
    // at 0.
    final xp = (state.xp - kXpPerTransactionLogged).clamp(0, state.xp);
    final coins = (state.coins - kCoinsPerTransactionLogged).clamp(
      0,
      state.coins,
    );

    // Drop `log:` from the window so a Phase 2 undo re-adds and re-awards
    // (delete-then-undo nets to zero); add `del:` so a duplicate delete no-ops.
    final window = _pushEvent(
      state.recentEventIds
          .where((id) => id != 'log:${e.transactionId}')
          .toList(growable: false),
      e.id,
    );

    final next = state.copyWith(
      xp: xp,
      coins: coins,
      level: levelForXp(xp),
      recentEventIds: window,
    );

    return GamificationResult(
      state: next,
      xpAwarded: next.xp - state.xp,
      coinsAwarded: next.coins - state.coins,
      streakBefore: state.currentStreak,
      streakAfter: next.currentStreak,
      newLevel: next.level,
    );
  }

  GamificationResult _budgetCreated(BudgetCreated e, GamificationState state) {
    var next = state.copyWith(budgetsCreated: state.budgetsCreated + 1);
    final unlocked = badgesUnlockedBy(next, e);
    next = next.copyWith(
      unlockedBadgeIds: <String>[...next.unlockedBadgeIds, ...unlocked],
      recentEventIds: _pushEvent(next.recentEventIds, e.id),
    );
    return GamificationResult(
      state: next,
      newlyUnlockedBadgeIds: unlocked,
      streakBefore: state.currentStreak,
      streakAfter: state.currentStreak,
      newLevel: state.level,
    );
  }

  GamificationResult _budgetPeriodCompleted(
    BudgetPeriodCompleted e,
    GamificationState state,
  ) {
    final within = e.stayedWithinLimit;
    final xp = state.xp + (within ? kXpBudgetPeriodWithinLimit : 0);
    final coins = state.coins + (within ? kCoinsBudgetPeriodWithinLimit : 0);

    var next = state.copyWith(
      xp: xp,
      coins: coins,
      level: levelForXp(xp),
      budgetPeriodsWithinLimit:
          state.budgetPeriodsWithinLimit + (within ? 1 : 0),
    );
    final unlocked = badgesUnlockedBy(next, e);
    next = next.copyWith(
      unlockedBadgeIds: <String>[...next.unlockedBadgeIds, ...unlocked],
      recentEventIds: _pushEvent(next.recentEventIds, e.id),
    );

    return GamificationResult(
      state: next,
      xpAwarded: next.xp - state.xp,
      coinsAwarded: next.coins - state.coins,
      newlyUnlockedBadgeIds: unlocked,
      streakBefore: state.currentStreak,
      streakAfter: state.currentStreak,
      leveledUp: next.level > state.level,
      newLevel: next.level,
    );
  }

  GamificationResult _dailyFirstLog(DailyFirstLog e, GamificationState state) {
    final streak = _rollStreak(state, e.occurredAt);
    final xp = state.xp + streak.xpBonus;
    final coins = state.coins + streak.coinBonus;
    var next = state.copyWith(
      xp: xp,
      coins: coins,
      level: levelForXp(xp),
      currentStreak: streak.streak,
      longestStreak: streak.longest,
      lastActivityDate: Patch<DateTime?>(streak.day),
    );
    final unlocked = badgesUnlockedBy(next, e);
    next = next.copyWith(
      unlockedBadgeIds: <String>[...next.unlockedBadgeIds, ...unlocked],
      recentEventIds: _pushEvent(next.recentEventIds, e.id),
    );
    return GamificationResult(
      state: next,
      xpAwarded: next.xp - state.xp,
      coinsAwarded: next.coins - state.coins,
      newlyUnlockedBadgeIds: unlocked,
      streakBefore: state.currentStreak,
      streakAfter: next.currentStreak,
      leveledUp: next.level > state.level,
      newLevel: next.level,
    );
  }

  // --- streak ------------------------------------------------------

  /// Rolls the streak for a log on calendar day [at]. Rules (CLAUDE.md §9):
  ///  - first ever log            -> streak 1, award daily bonus
  ///  - same calendar day again   -> no change, no bonus
  ///  - exactly the next day      -> streak + 1, award daily bonus
  ///  - one or more days missed   -> streak resets to 1, award daily bonus
  ///  - a day *before* the anchor -> **no change, no bonus** (backdated logs /
  ///    a clock moved backwards never repair or inflate a streak — streaks
  ///    track logging behaviour, not transaction dates)
  ///  - `longestStreak` never decreases.
  ({int streak, int longest, DateTime day, int xpBonus, int coinBonus})
  _rollStreak(GamificationState s, DateTime at) {
    final today = _dateOnly(at);
    final last = s.lastActivityDate == null
        ? null
        : _dateOnly(s.lastActivityDate!);

    if (last == null) {
      return (
        streak: 1,
        longest: s.longestStreak < 1 ? 1 : s.longestStreak,
        day: today,
        xpBonus: kXpDailyFirstLog,
        coinBonus: kCoinsDailyFirstLog,
      );
    }

    final diff = _dayNumber(today) - _dayNumber(last);
    if (diff <= 0) {
      // same day, or backdated / clock-backwards -> unchanged, no bonus
      return (
        streak: s.currentStreak,
        longest: s.longestStreak,
        day: last,
        xpBonus: 0,
        coinBonus: 0,
      );
    }

    final streak = diff == 1 ? s.currentStreak + 1 : 1;
    return (
      streak: streak,
      longest: streak > s.longestStreak ? streak : s.longestStreak,
      day: today,
      xpBonus: kXpDailyFirstLog,
      coinBonus: kCoinsDailyFirstLog,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole-day index, computed in UTC so a DST change or a device timezone
  /// change can never produce a fractional or negative day count.
  static int _dayNumber(DateTime dateOnly) =>
      DateTime.utc(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static List<String> _pushEvent(List<String> window, String id) {
    final next = <String>[id, ...window.where((e) => e != id)];
    if (next.length > kRecentEventWindow) {
      return next.sublist(0, kRecentEventWindow);
    }
    return next;
  }
}

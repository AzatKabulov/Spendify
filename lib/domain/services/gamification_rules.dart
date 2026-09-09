/// Tunable gamification award amounts and the level curve, in one place
/// (Phase 8). Pure — no imports, no I/O.
///
/// **Ethics (CLAUDE.md §7):** every constant here rewards a *budgeting action*.
/// There is deliberately no reward for opening the app, session length, or
/// screen views. Do not add one.
library;

// --- award amounts -------------------------------------------------------

/// Logging any transaction (manual or scanned).
const int kXpPerTransactionLogged = 5;
const int kCoinsPerTransactionLogged = 2;

/// Bonus for the first transaction logged on a new calendar day — the
/// consistency reward that also carries the streak.
const int kXpDailyFirstLog = 10;
const int kCoinsDailyFirstLog = 5;

/// Finishing a whole budget period without exceeding the limit — the big one.
const int kXpBudgetPeriodWithinLimit = 60;
const int kCoinsBudgetPeriodWithinLimit = 30;

/// Exceeding a budget: no reward, and **no penalty** (we inform, we don't
/// punish — CLAUDE.md §7 informational-not-punitive).
const int kXpBudgetPeriodExceeded = 0;
const int kCoinsBudgetPeriodExceeded = 0;

/// Cap on `GamificationState.recentEventIds` — the idempotency / XP-reversal
/// window. Big enough that any realistic double-fire or delete-then-undo is
/// caught; small enough to sync cheaply.
const int kRecentEventWindow = 300;

// --- level curve -------------------------------------------------------

/// Cumulative XP required to *reach* [level] (1-based).
///
///   threshold(L) = 50 * L * (L + 1) - 100
///
/// So: L1 = 0, L2 = 200, L3 = 500, L4 = 900, L5 = 1400, L6 = 2000 …
/// The gap between levels grows by a flat 100 XP each level, so early levels
/// come fast (a couple of budget periods) and later ones take sustained use.
int xpThresholdForLevel(int level) {
  if (level <= 1) return 0;
  return 50 * level * (level + 1) - 100;
}

/// The level for a given lifetime [xp] (>= 1). Level tracks XP exactly, so
/// enough deletions *can* lower it — XP is the single source of truth.
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  var level = 1;
  while (xpThresholdForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// Where [xp] sits within its current level, for the stats-screen progress bar.
///  - [level]     : current level
///  - [intoLevel] : XP earned since reaching [level] (>= 0)
///  - [levelSpan] : total XP between [level] and the next (> 0)
///  - [toNext]    : XP still needed to reach the next level (>= 0)
({int level, int intoLevel, int levelSpan, int toNext}) levelProgress(int xp) {
  final level = levelForXp(xp);
  final base = xpThresholdForLevel(level);
  final next = xpThresholdForLevel(level + 1);
  final clamped = xp < base ? base : xp;
  return (
    level: level,
    intoLevel: clamped - base,
    levelSpan: next - base,
    toNext: next - clamped,
  );
}

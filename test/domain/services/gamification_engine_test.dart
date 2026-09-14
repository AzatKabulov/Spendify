import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/gamification_state.dart';
import 'package:spendify/domain/services/gamification_engine.dart';
import 'package:spendify/domain/services/gamification_rules.dart';

const _engine = GamificationEngine();

GamificationState _fresh({DateTime? now}) => GamificationState.initial(
  userId: 'u',
  now: now ?? DateTime.utc(2026, 9, 9),
);

TransactionLogged _log(
  String id, {
  DateTime? at,
  TransactionSource source = TransactionSource.manual,
  bool allCategoriesUsed = false,
}) => TransactionLogged(
  transactionId: id,
  source: source,
  loggedAt: at ?? DateTime(2026, 9, 9, 10),
  allCategoriesUsed: allCategoriesUsed,
);

/// Apply a list of events in order, returning the final state.
GamificationState _run(
  List<GamificationEvent> events, {
  GamificationState? from,
}) {
  var state = from ?? _fresh();
  for (final e in events) {
    state = _engine.process(e, state).state;
  }
  return state;
}

void main() {
  group('award amounts', () {
    test(
      'logging a transaction awards XP + coins (+ the daily bonus once)',
      () {
        final r = _engine.process(_log('t1'), _fresh());
        // first log of the day -> per-log award + daily bonus
        expect(r.xpAwarded, kXpPerTransactionLogged + kXpDailyFirstLog);
        expect(
          r.coinsAwarded,
          kCoinsPerTransactionLogged + kCoinsDailyFirstLog,
        );
        expect(r.state.transactionsLogged, 1);
      },
    );

    test(
      'a second log the same day gets the per-log award, no daily bonus',
      () {
        final state = _engine.process(_log('t1'), _fresh()).state;
        final r = _engine.process(
          _log('t2', at: DateTime(2026, 9, 9, 18)),
          state,
        );
        expect(r.xpAwarded, kXpPerTransactionLogged);
        expect(r.coinsAwarded, kCoinsPerTransactionLogged);
        expect(r.streakAfter, 1); // still 1 — same day
      },
    );

    test('completing a budget period within limit is the big award', () {
      final r = _engine.process(
        BudgetPeriodCompleted(
          budgetId: 'b1',
          periodKey: '2026-W36',
          period: BudgetPeriod.weekly,
          stayedWithinLimit: true,
          completedAt: DateTime(2026, 9, 8),
        ),
        _fresh(),
      );
      expect(r.xpAwarded, kXpBudgetPeriodWithinLimit);
      expect(r.coinsAwarded, kCoinsBudgetPeriodWithinLimit);
      expect(r.state.budgetPeriodsWithinLimit, 1);
    });

    test('exceeding a budget period awards nothing and never penalises', () {
      final start = _fresh().copyWith(xp: 100, coins: 40);
      final r = _engine.process(
        BudgetPeriodCompleted(
          budgetId: 'b1',
          periodKey: '2026-09',
          period: BudgetPeriod.monthly,
          stayedWithinLimit: false,
          completedAt: DateTime(2026, 10, 1),
        ),
        start,
      );
      expect(r.xpAwarded, 0);
      expect(r.coinsAwarded, 0);
      expect(r.state.xp, 100); // unchanged, not reduced
    });
  });

  group('idempotency', () {
    test('the same TransactionLogged twice awards once', () {
      final e = _log('t1');
      final s1 = _engine.process(e, _fresh()).state;
      final r2 = _engine.process(e, s1); // same event id
      expect(r2.isNoop, isTrue);
      expect(r2.state.xp, s1.xp);
      expect(r2.state.transactionsLogged, 1);
    });

    test('the same BudgetPeriodCompleted twice awards once', () {
      final e = BudgetPeriodCompleted(
        budgetId: 'b1',
        periodKey: '2026-W36',
        period: BudgetPeriod.weekly,
        stayedWithinLimit: true,
        completedAt: DateTime(2026, 9, 8),
      );
      final s1 = _engine.process(e, _fresh()).state;
      final r2 = _engine.process(e, s1);
      expect(r2.state.xp, s1.xp);
      expect(r2.state.budgetPeriodsWithinLimit, 1);
    });
  });

  group('delete / reversal', () {
    test('delete reverses the per-log XP + coins (not the daily bonus)', () {
      final s1 = _engine.process(_log('t1'), _fresh()).state;
      final r = _engine.process(
        TransactionDeleted(
          transactionId: 't1',
          deletedAt: DateTime(2026, 9, 9),
        ),
        s1,
      );
      expect(r.xpAwarded, -kXpPerTransactionLogged);
      expect(r.coinsAwarded, -kCoinsPerTransactionLogged);
      // daily bonus + streak + lifetime count are untouched
      expect(r.state.xp, kXpDailyFirstLog);
      expect(r.state.currentStreak, 1);
      expect(r.state.transactionsLogged, 1);
    });

    test('XP floors at 0, never negative', () {
      // a state with only the per-log award and nothing else
      final state = _fresh().copyWith(
        xp: 3, // less than kXpPerTransactionLogged
        recentEventIds: const ['log:t1'],
      );
      final r = _engine.process(
        TransactionDeleted(
          transactionId: 't1',
          deletedAt: DateTime(2026, 9, 9),
        ),
        state,
      );
      expect(r.state.xp, 0);
      expect(r.state.coins, 0);
    });

    test(
      'delete of a never-awarded (e.g. synced-in) transaction is a no-op',
      () {
        final r = _engine.process(
          TransactionDeleted(
            transactionId: 'from-sync',
            deletedAt: DateTime(2026, 9, 9),
          ),
          _fresh().copyWith(xp: 500),
        );
        expect(r.isNoop, isTrue);
        expect(r.state.xp, 500);
      },
    );

    test('delete does not revoke a badge or reduce longestStreak', () {
      // reach the first_transaction badge + a 3-day streak
      var state = _run([
        _log('t1', at: DateTime(2026, 9, 7, 9)),
        _log('t2', at: DateTime(2026, 9, 8, 9)),
        _log('t3', at: DateTime(2026, 9, 9, 9)),
      ]);
      expect(state.unlockedBadgeIds, contains('first_transaction'));
      expect(state.unlockedBadgeIds, contains('streak_3'));
      expect(state.longestStreak, 3);

      state = _engine
          .process(
            TransactionDeleted(
              transactionId: 't3',
              deletedAt: DateTime(2026, 9, 9),
            ),
            state,
          )
          .state;
      expect(state.unlockedBadgeIds, contains('first_transaction'));
      expect(state.unlockedBadgeIds, contains('streak_3'));
      expect(state.longestStreak, 3);
    });
  });

  test('delete-then-undo nets to zero change', () {
    final base = _fresh();
    final afterCreate = _engine.process(_log('t1'), base).state;

    final afterDelete = _engine
        .process(
          TransactionDeleted(
            transactionId: 't1',
            deletedAt: DateTime(2026, 9, 9, 11),
          ),
          afterCreate,
        )
        .state;
    // undo re-adds the row -> the same TransactionLogged fires again
    final afterUndo = _engine.process(_log('t1'), afterDelete).state;

    expect(afterUndo.xp, afterCreate.xp);
    expect(afterUndo.coins, afterCreate.coins);
    expect(
      afterUndo.transactionsLogged,
      afterCreate.transactionsLogged + 1,
      reason: 'lifetime count is never decremented; undo counts as a new log',
    );
    expect(afterUndo.currentStreak, afterCreate.currentStreak);
  });

  group('badges', () {
    test('unlock at exact thresholds and never revoke', () {
      var state = _fresh();
      for (var i = 1; i <= 10; i++) {
        final r = _engine.process(_log('t$i'), state);
        state = r.state;
        if (i == 1) {
          expect(r.newlyUnlockedBadgeIds, contains('first_transaction'));
        }
        if (i == 9) {
          expect(state.unlockedBadgeIds, isNot(contains('transactions_10')));
        }
        if (i == 10) {
          expect(r.newlyUnlockedBadgeIds, contains('transactions_10'));
        }
      }
      // logging an 11th does not re-award transactions_10
      final r11 = _engine.process(_log('t11'), state);
      expect(r11.newlyUnlockedBadgeIds, isNot(contains('transactions_10')));
    });

    test('first_scan unlocks on the first scanned log only', () {
      final r1 = _engine.process(
        _log('t1', source: TransactionSource.scanned),
        _fresh(),
      );
      expect(r1.newlyUnlockedBadgeIds, contains('first_scan'));
      final r2 = _engine.process(
        _log(
          't2',
          source: TransactionSource.scanned,
          at: DateTime(2026, 9, 9, 12),
        ),
        r1.state,
      );
      expect(r2.newlyUnlockedBadgeIds, isNot(contains('first_scan')));
    });

    test(
      'all_categories unlocks when the event says every category is used',
      () {
        final r = _engine.process(
          _log('t1', allCategoriesUsed: true),
          _fresh(),
        );
        expect(r.newlyUnlockedBadgeIds, contains('all_categories'));
      },
    );

    test('first_budget unlocks on BudgetCreated', () {
      final r = _engine.process(
        BudgetCreated(budgetId: 'b1', createdAt: DateTime(2026, 9, 9)),
        _fresh(),
      );
      expect(r.newlyUnlockedBadgeIds, contains('first_budget'));
      expect(r.state.budgetsCreated, 1);
    });
  });

  group('streak', () {
    test('consecutive days increment', () {
      final state = _run([
        _log('a', at: DateTime(2026, 9, 7, 9)),
        _log('b', at: DateTime(2026, 9, 8, 9)),
        _log('c', at: DateTime(2026, 9, 9, 9)),
      ]);
      expect(state.currentStreak, 3);
      expect(state.longestStreak, 3);
    });

    test('two logs in one day increment the streak once', () {
      final state = _run([
        _log('a', at: DateTime(2026, 9, 8, 9)),
        _log('b', at: DateTime(2026, 9, 9, 8)),
        _log('c', at: DateTime(2026, 9, 9, 22)),
      ]);
      expect(state.currentStreak, 2);
    });

    test('a fully missed day resets the streak to 1 (not 0)', () {
      final state = _run([
        _log('a', at: DateTime(2026, 9, 6, 9)),
        _log('b', at: DateTime(2026, 9, 7, 9)), // streak 2
        _log('c', at: DateTime(2026, 9, 10, 9)), // skipped 8th & 9th
      ]);
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 2); // preserved
    });

    test('a backdated transaction does NOT repair a broken streak', () {
      var state = _run([
        _log('a', at: DateTime(2026, 9, 6, 9)),
        _log('b', at: DateTime(2026, 9, 7, 9)),
        _log('c', at: DateTime(2026, 9, 10, 9)), // streak broke -> now 1
      ]);
      expect(state.currentStreak, 1);
      // user logs "yesterday's" (9th) expense on the 10th
      state = _engine
          .process(_log('d', at: DateTime(2026, 9, 9, 9)), state)
          .state;
      expect(state.currentStreak, 1, reason: 'backdated log must not repair');
      expect(state.lastActivityDate, DateTime(2026, 9, 10));
    });

    test('longestStreak never decreases', () {
      var state = _run([
        for (var d = 1; d <= 8; d++) _log('d$d', at: DateTime(2026, 9, d, 9)),
      ]);
      expect(state.longestStreak, 8);
      // miss a week, log again
      state = _engine
          .process(_log('later', at: DateTime(2026, 9, 20, 9)), state)
          .state;
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 8);
    });

    test('midnight boundary: 23:59 then 00:01 next day increments', () {
      final state = _run([
        _log('a', at: DateTime(2026, 9, 9, 23, 59)),
        _log('b', at: DateTime(2026, 9, 10, 0, 1)),
      ]);
      expect(state.currentStreak, 2);
    });

    test('a clock/timezone jump backwards does not crash or go negative', () {
      final state = _run([_log('a', at: DateTime(2026, 9, 10, 9))]);
      expect(state.currentStreak, 1);
      // device clock jumps back a month
      final r = _engine.process(_log('b', at: DateTime(2026, 8, 10, 9)), state);
      expect(r.state.currentStreak, greaterThanOrEqualTo(0));
      expect(r.state.currentStreak, 1); // unchanged — treated like a backdate
    });
  });

  group('levelling', () {
    test('level-up fires at the exact XP threshold', () {
      // threshold for L2 is 200 XP.
      final state = _fresh().copyWith(xp: xpThresholdForLevel(2) - 1, level: 1);
      // a within-limit budget period adds kXpBudgetPeriodWithinLimit (60),
      // pushing past 200.
      final r = _engine.process(
        BudgetPeriodCompleted(
          budgetId: 'b1',
          periodKey: '2026-09',
          period: BudgetPeriod.monthly,
          stayedWithinLimit: true,
          completedAt: DateTime(2026, 10, 1),
        ),
        state,
      );
      expect(r.leveledUp, isTrue);
      expect(r.newLevel, 2);
      expect(r.state.level, 2);
    });

    test('exactly on the threshold is the new level, not one below', () {
      expect(levelForXp(xpThresholdForLevel(3)), 3);
      expect(levelForXp(xpThresholdForLevel(3) - 1), 2);
    });

    test('level_5 badge unlocks when the level reaches 5', () {
      final state = _fresh().copyWith(xp: xpThresholdForLevel(5) - 5, level: 4);
      final r = _engine.process(_log('t1'), state); // +5 per-log +10 daily
      expect(r.state.level, greaterThanOrEqualTo(5));
      expect(r.newlyUnlockedBadgeIds, contains('level_5'));
    });
  });

  test('recentEventIds stays bounded', () {
    var state = _fresh();
    for (var i = 0; i < kRecentEventWindow + 50; i++) {
      state = _engine
          .process(
            _log('t$i', at: DateTime(2026, 9, 9, 12).add(Duration(seconds: i))),
            state,
          )
          .state;
    }
    expect(state.recentEventIds.length, kRecentEventWindow);
  });
}

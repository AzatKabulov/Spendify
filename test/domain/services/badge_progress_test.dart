import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/badge_catalogue.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/gamification_state.dart';
import 'package:spendify/domain/services/badge_progress.dart';
import 'package:spendify/domain/services/badge_rules.dart';
import 'package:spendify/domain/services/gamification_engine.dart';
import 'package:spendify/domain/services/gamification_rules.dart';

/// `badge_progress.dart` duplicates the thresholds that `badge_rules.dart`
/// uses to actually unlock a badge. These tests are the thing that keeps the
/// two honest: a progress bar that fills before (or after) the badge unlocks
/// is exactly the bug this file exists to catch.

GamificationState _state({
  int transactionsLogged = 0,
  int budgetsCreated = 0,
  int budgetPeriodsWithinLimit = 0,
  int scannedTransactionsLogged = 0,
  int longestStreak = 0,
  int xp = 0,
  List<String> unlocked = const <String>[],
}) => GamificationState(
  userId: kLocalUserId,
  updatedAt: DateTime.utc(2026, 9, 15),
  xp: xp,
  level: levelForXp(xp),
  longestStreak: longestStreak,
  unlockedBadgeIds: unlocked,
  transactionsLogged: transactionsLogged,
  budgetsCreated: budgetsCreated,
  budgetPeriodsWithinLimit: budgetPeriodsWithinLimit,
  scannedTransactionsLogged: scannedTransactionsLogged,
);

/// A state sitting exactly on [badgeId]'s threshold, built from the target
/// `badgeProgressFor` reports. Returns `null` for badges with no counter.
GamificationState? _stateAtThresholdFor(String badgeId, int target) {
  switch (badgeId) {
    case 'first_transaction':
    case 'transactions_10':
    case 'transactions_50':
    case 'transactions_100':
      return _state(transactionsLogged: target);
    case 'first_budget':
      return _state(budgetsCreated: target);
    case 'budget_kept':
      return _state(budgetPeriodsWithinLimit: target);
    case 'streak_3':
    case 'streak_7':
    case 'streak_30':
      return _state(longestStreak: target);
    case 'first_scan':
      return _state(scannedTransactionsLogged: target);
    case 'level_5':
    case 'level_10':
      return _state(xp: xpThresholdForLevel(target));
    default:
      return null;
  }
}

void main() {
  // A bare event: every criterion under test is read off the state, not the
  // event, so which one this is does not matter.
  final event = TransactionLogged(
    transactionId: 't-1',
    source: TransactionSource.manual,
    loggedAt: DateTime.utc(2026, 9, 15, 12),
  );

  group('thresholds agree with badge_rules', () {
    for (final badge in kBadgeCatalogue) {
      test('${badge.id} unlocks exactly at its reported target', () {
        final target = badgeProgressFor(_state(), badge.id).target;
        final atThreshold = _stateAtThresholdFor(badge.id, target);

        if (atThreshold == null) {
          // Not a counted badge — progress must say so rather than showing a
          // bar that can never move.
          expect(
            badgeProgressFor(_state(), badge.id).isCountable,
            isFalse,
            reason: '${badge.id} has no counter to drive a progress bar',
          );
          return;
        }

        expect(target, greaterThan(0), reason: badge.id);
        expect(
          badgesUnlockedBy(atThreshold, event),
          contains(badge.id),
          reason: '${badge.id} should unlock at $target',
        );

        final belowTarget = _stateAtThresholdFor(badge.id, target - 1)!;
        expect(
          badgesUnlockedBy(belowTarget, event),
          isNot(contains(badge.id)),
          reason: '${badge.id} must not unlock one short of $target',
        );
      });
    }
  });

  test('every catalogue badge is in a group', () {
    for (final badge in kBadgeCatalogue) {
      expect(() => badgeGroupFor(badge.id), returnsNormally);
    }
    expect(allBadgeIds.length, kBadgeCatalogue.length);
  });

  group('BadgeProgress', () {
    test('fraction is clamped to 0..1 and full once unlocked', () {
      final partway = badgeProgressFor(
        _state(transactionsLogged: 5),
        'transactions_10',
      );
      expect(partway.fraction, 0.5);
      expect(partway.inProgress, isTrue);
      expect(partway.unlocked, isFalse);

      // An unlocked badge stays full even if the counter later reads low —
      // XP (and so level) can fall when a transaction is deleted.
      final held = badgeProgressFor(
        _state(xp: 0, unlocked: const ['level_5']),
        'level_5',
      );
      expect(held.unlocked, isTrue);
      expect(held.fraction, 1.0);
    });

    test('current never reports past the target', () {
      final over = badgeProgressFor(
        _state(transactionsLogged: 500),
        'transactions_10',
      );
      expect(over.current, 10);
      expect(over.fraction, 1.0);
    });

    test('an unknown id is locked with nothing to count', () {
      final unknown = badgeProgressFor(_state(), 'not_a_badge');
      expect(unknown.unlocked, isFalse);
      expect(unknown.isCountable, isFalse);
      expect(unknown.fraction, 0);
    });
  });
}

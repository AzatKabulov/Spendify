import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/gamification_state.dart';
import 'package:spendify/domain/services/gamification_rules.dart';
import 'package:spendify/presentation/screens/achievements_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/stats_screen.dart';
import 'package:spendify/presentation/screens/your_stats_screen.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  testWidgets('shows level, coins, streak and recent achievements', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const StatsScreen());

    await repos.gamification.save(
      GamificationState(
        userId: kLocalUserId,
        updatedAt: DateTime.utc(2026, 9, 9),
        xp: xpThresholdForLevel(3) + 20,
        coins: 42,
        currentStreak: 4,
        longestStreak: 9,
        unlockedBadgeIds: const ['first_transaction', 'streak_3'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text(levelTitle(3)), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets); // coins
    expect(find.text('4 days in a row'), findsOneWidget);
    expect(find.text('Best: 9 days'), findsOneWidget);
    expect(find.text('2/13'), findsOneWidget); // achievements tile

    // Recent achievements lists the unlocked ones, newest first. A locked
    // badge is NOT on this screen — it lives on Achievements.
    expect(find.text('Warming Up'), findsOneWidget); // streak_3
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Century'), findsNothing); // locked
  });

  testWidgets('fresh state renders at level 1 with nothing unlocked', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const StatsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0/13'), findsOneWidget);
    expect(find.textContaining('Nothing unlocked yet'), findsOneWidget);
  });

  testWidgets('"See all" opens the full achievement catalogue', (tester) async {
    await pumpSpendify(tester, home: const StatsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(AchievementsScreen), findsOneWidget);
    expect(find.text('Your Progress'), findsOneWidget);
    expect(find.text('0 / 13'), findsOneWidget);
    // Locked badges are listed with what it takes to earn them.
    expect(find.text('Century'), findsOneWidget);
    expect(find.text('Log 100 transactions.'), findsOneWidget);
  });

  testWidgets('the achievement filters narrow the catalogue', (tester) async {
    final repos = await pumpSpendify(tester, home: const AchievementsScreen());
    await repos.gamification.save(
      GamificationState(
        userId: kLocalUserId,
        updatedAt: DateTime.utc(2026, 9, 9),
        unlockedBadgeIds: const ['first_transaction'],
        transactionsLogged: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Century'), findsNothing);

    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
    expect(find.text('First Steps'), findsNothing);
    expect(find.text('Century'), findsOneWidget);

    // Narrow to a single group.
    await tester.tap(find.text('Streaks'));
    await tester.pumpAndSettle();
    expect(find.text('Century'), findsNothing);
    expect(find.text('Unbroken'), findsOneWidget); // streak_30
  });

  testWidgets('Your Stats opens from Rewards and shows lifetime counters', (
    tester,
  ) async {
    final repos = await pumpSpendify(tester, home: const StatsScreen());
    await repos.gamification.save(
      GamificationState(
        userId: kLocalUserId,
        updatedAt: DateTime.utc(2026, 9, 9),
        transactionsLogged: 7,
        budgetsCreated: 2,
        longestStreak: 5,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Your Stats'));
    await tester.pumpAndSettle();

    expect(find.byType(YourStatsScreen), findsOneWidget);
    expect(find.text('Transactions logged'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
    expect(find.text('Budgets created'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget); // longest streak
  });

  testWidgets('reachable from the Home quick actions', (tester) async {
    await pumpSpendify(tester, home: const HomeScreen());

    // With AI off the second quick action is Rewards.
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);
  });

  testWidgets('nothing on Rewards rewards mere app usage', (tester) async {
    // CLAUDE.md §7.2: XP and coins come from budgeting actions only. This is
    // a copy guard — no "come back", "daily visit" or "check in" language.
    await pumpSpendify(tester, home: const StatsScreen());
    await tester.pumpAndSettle();

    for (final banned in <String>[
      'check in',
      'come back',
      'daily visit',
      'open the app',
      'time spent',
    ]) {
      expect(
        find.textContaining(banned, findRichText: true),
        findsNothing,
        reason: banned,
      );
    }
  });
}

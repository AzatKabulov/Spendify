import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/gamification_state.dart';
import 'package:spendify/domain/services/gamification_rules.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/stats_screen.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  testWidgets('shows level, coins, streak and the badge grid', (tester) async {
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
    expect(find.textContaining('42'), findsWidgets); // coins
    expect(find.text('Badges  2/13'), findsOneWidget);

    // an unlocked badge shows its name; a locked one is still listed
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Century'), findsOneWidget); // locked, still shown
  });

  testWidgets('fresh state renders at level 1 with no badges', (tester) async {
    await pumpSpendify(tester, home: const StatsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Badges  0/13'), findsOneWidget);
  });

  testWidgets('reachable from the home overflow menu', (tester) async {
    await pumpSpendify(tester, home: const HomeScreen());

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);
  });
}

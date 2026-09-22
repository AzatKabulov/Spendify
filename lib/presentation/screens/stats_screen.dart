import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/badge_catalogue.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/services/badge_progress.dart';
import '../../domain/services/gamification_rules.dart';
import '../providers/gamification_providers.dart';
import '../providers/rewards_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/rewards/rewards_widgets.dart';
import 'achievements_screen.dart';
import 'your_stats_screen.dart';

/// "Rewards" — the persistent view of progress (level, coins, streak,
/// achievements). The immediate per-action feedback is the SnackBar from
/// `GamificationFeedbackListener`; this screen is where it all adds up.
///
/// **Ethics (CLAUDE.md §7.2):** everything rewarded here is a budgeting
/// action — logging, keeping to a limit, logging consistently. There is
/// nothing for opening the app or for time spent in it, and no copy on this
/// screen asks the user to come back more often.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(gamificationStateProvider);
    final week = ref.watch(currentWeekActivityProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Rewards',
              subtitle: 'Your budgeting progress',
            ),
            Expanded(
              child: stateAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: "Couldn't load your rewards.",
                  detail: e,
                  onRetry: () => ref.invalidate(gamificationStateProvider),
                ),
                data: (state) => _RewardsBody(state: state, week: week),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsBody extends StatelessWidget {
  const _RewardsBody({required this.state, required this.week});

  final GamificationState state;
  final List<ActivityDay> week;

  /// A line of encouragement picked from what the user has actually done.
  /// Deliberately about the budgeting habit, never about app usage.
  String get _note {
    if (state.transactionsLogged == 0) {
      return "Log your first transaction and you're on the board. "
          'Every badge here starts with one.';
    }
    if (state.budgetPeriodsWithinLimit > 0) {
      return 'You finished ${state.budgetPeriodsWithinLimit} budget '
          '${state.budgetPeriodsWithinLimit == 1 ? 'period' : 'periods'} '
          'inside the limit. That is the hard part, and you did it.';
    }
    if (state.currentStreak >= 3) {
      return '${state.currentStreak} days of logging in a row. '
          'Consistency is what makes the numbers worth reading.';
    }
    if (state.budgetsCreated == 0) {
      return 'Set a spending limit next — budgets are where the biggest '
          'rewards here come from.';
    }
    return 'Keep logging as you spend. A complete picture is what makes '
        'your reports honest.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = levelProgress(state.xp);
    final unlocked = state.unlockedBadgeIds.toSet();

    // `unlockedBadgeIds` is appended to in unlock order, so the tail is the
    // most recent. Unlock *dates* are not stored — nothing here shows one.
    final recent = <Badge>[
      for (final id in state.unlockedBadgeIds.reversed.take(3)) ?badgeById(id),
    ];

    void openAchievements() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
      children: <Widget>[
        LevelHeroCard(
          level: progress.level,
          title: levelTitle(progress.level),
          nextTitle: levelTitle(progress.level + 1),
          coins: state.coins,
          intoLevel: progress.intoLevel,
          levelSpan: progress.levelSpan,
          toNext: progress.toNext,
        ),
        const SizedBox(height: Insets.md - 2),
        MascotNoteCard(message: _note),
        const SizedBox(height: Insets.md - 2),
        StreakCard(
          currentStreak: state.currentStreak,
          longestStreak: state.longestStreak,
          week: week,
        ),
        const SizedBox(height: Insets.md - 2),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: RewardStatTile(
                  icon: Icons.bolt_rounded,
                  value: '${state.xp}',
                  label: 'Total XP',
                ),
              ),
              const SizedBox(width: Insets.sm + 2),
              Expanded(
                child: RewardStatTile(
                  icon: Icons.monetization_on_rounded,
                  value: '${state.coins}',
                  label: 'Coins',
                  tint: scheme.tertiary,
                ),
              ),
              const SizedBox(width: Insets.sm + 2),
              Expanded(
                child: RewardStatTile(
                  icon: Icons.emoji_events_rounded,
                  value: '${unlocked.length}/${kBadgeCatalogue.length}',
                  label: 'Achievements',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md - 2),
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Recent Achievements',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: openAchievements,
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: Insets.xs,
                    bottom: Insets.sm,
                  ),
                  child: Text(
                    'Nothing unlocked yet. There are '
                    '${kBadgeCatalogue.length} to earn — all of them for '
                    'budgeting, none for screen time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                )
              else
                for (final badge in recent)
                  AchievementRow(
                    badge: badge,
                    progress: badgeProgressFor(state, badge.id),
                  ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md - 2),
        HomeCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const YourStatsScreen()),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.query_stats_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Insets.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your Stats',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Activity, active days and totals over time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/badge_icons.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/badge_catalogue.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/services/gamification_rules.dart';
import '../providers/gamification_providers.dart';

/// "Rewards" — the persistent view of progress (level, coins, streak, badges).
/// The immediate per-action feedback is the SnackBar from
/// `GamificationFeedbackListener`; this screen is where it all adds up.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(gamificationStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load rewards: $e')),
        data: (state) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _LevelCard(state: state),
            const SizedBox(height: 12),
            _StatsRow(state: state),
            const SizedBox(height: 24),
            _BadgesSection(unlocked: state.unlockedBadgeIds.toSet()),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = levelProgress(state.xp);
    final fraction = progress.levelSpan == 0
        ? 0.0
        : progress.intoLevel / progress.levelSpan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  'Level ${progress.level}',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                Text('${state.xp} XP', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress.toNext > 0
                  ? '${progress.toNext} XP to level ${progress.level + 1}'
                  : 'Max level reached',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            icon: Icons.toll_outlined,
            label: 'Coins',
            value: '${state.coins}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_outlined,
            label: 'Streak',
            value: state.currentStreak == 1
                ? '1 day'
                : '${state.currentStreak} days',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_outlined,
            label: 'Best',
            value: state.longestStreak == 1
                ? '1 day'
                : '${state.longestStreak} days',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.unlocked});

  final Set<String> unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Badges  ${unlocked.length}/${kBadgeCatalogue.length}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: <Widget>[
            for (final badge in kBadgeCatalogue)
              _BadgeTile(badge: badge, unlocked: unlocked.contains(badge.id)),
          ],
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});

  final Badge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Tooltip(
      message: unlocked ? badge.description : badge.criteriaDescription,
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Column(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: unlocked
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              child: Icon(
                unlocked
                    ? badgeIconForCode(badge.iconCode)
                    : Icons.lock_outline,
                color: unlocked ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

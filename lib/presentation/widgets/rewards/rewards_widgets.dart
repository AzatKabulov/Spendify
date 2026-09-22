import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';

import '../../../core/badge_icons.dart';
import '../../../core/theme/insets.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/services/badge_progress.dart';
import '../../providers/rewards_providers.dart';
import '../auth/auth_illustrations.dart';
import '../home/home_sections.dart';

/// Building blocks of the Rewards / Achievements / Your Stats screens.
/// All presentational: each is handed resolved values and callbacks.
///
/// **Nothing here invents a figure.** Every number rendered below is one the
/// app actually stores (`GamificationState`) or can derive from the cached
/// daily aggregates. Per-badge XP values and badge unlock dates are *not*
/// recorded anywhere, so no widget here shows them.

/// The dark level card at the top of Rewards.
class LevelHeroCard extends StatelessWidget {
  const LevelHeroCard({
    required this.level,
    required this.title,
    required this.nextTitle,
    required this.coins,
    required this.intoLevel,
    required this.levelSpan,
    required this.toNext,
    super.key,
  });

  final int level;
  final String title;
  final String nextTitle;
  final int coins;
  final int intoLevel;
  final int levelSpan;
  final int toNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = levelSpan == 0
        ? 1.0
        : (intoLevel / levelSpan).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(Insets.md + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.onPrimaryContainer,
            Color.lerp(scheme.onPrimaryContainer, scheme.primary, 0.75)!,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 34,
                  height: 43,
                  child: FittedBox(child: AssistantMascot()),
                ),
              ),
              const SizedBox(width: Insets.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Level $level',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              _CoinPill(coins: coins),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Text(
                'Progress to level ${level + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const Spacer(),
              Text(
                '$intoLevel / $levelSpan XP',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: Insets.sm + 2),
          Text(
            'Next level: $nextTitle  ·  $toNext XP to go',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm + 2,
        vertical: Insets.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.monetization_on_rounded,
            size: 18,
            color: Color(0xFFFFD75E),
          ),
          const SizedBox(width: Insets.xs + 2),
          Text(
            NumberFormat.decimalPattern().format(coins),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short line of encouragement from the mascot, chosen from the user's own
/// state — never a reward for opening the app, and never a nudge to come back
/// more often (CLAUDE.md §7.2).
class MascotNoteCard extends StatelessWidget {
  const MascotNoteCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 38,
            height: 48,
            child: FittedBox(child: AssistantMascot()),
          ),
          const SizedBox(width: Insets.sm + 4),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current streak plus the seven days of this week, so the number is
/// verifiable at a glance rather than something the user has to trust.
class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.currentStreak,
    required this.longestStreak,
    required this.week,
    super.key,
  });

  final int currentStreak;
  final int longestStreak;
  final List<ActivityDay> week;

  static String _days(int n) => n == 1 ? '1 day' : '$n days';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: currentStreak > 0
                      ? scheme.tertiaryContainer
                      : scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: currentStreak > 0
                      ? scheme.tertiary
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Insets.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currentStreak > 0
                          ? '${_days(currentStreak)} in a row'
                          : 'No streak yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Best: ${_days(longestStreak)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          WeekActivityStrip(week: week),
        ],
      ),
    );
  }
}

/// Monday-first row of seven day markers: filled where the user logged
/// something, hollow where they did not, dashed for days still to come.
class WeekActivityStrip extends StatelessWidget {
  const WeekActivityStrip({required this.week, super.key});

  final List<ActivityDay> week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = DateFormat.EEEE().dateSymbols.NARROWWEEKDAYS;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          for (final day in week)
            Semantics(
              label:
                  '${DateFormat('EEEE d MMMM').format(day.date)}: '
                  '${day.isFuture
                      ? 'upcoming'
                      : day.hasActivity
                      ? '${day.transactionCount} logged'
                      : 'nothing logged'}',
              child: ExcludeSemantics(
                child: Column(
                  children: <Widget>[
                    Text(
                      // NARROWWEEKDAYS is Sunday-first; the strip is
                      // Monday-first.
                      initials[day.date.weekday % 7],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.xs + 2),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day.hasActivity
                            ? scheme.primary
                            : Colors.transparent,
                        border: day.hasActivity
                            ? null
                            : Border.all(
                                color: day.isFuture
                                    ? scheme.outlineVariant
                                    : scheme.outline.withValues(alpha: 0.5),
                              ),
                      ),
                      child: day.hasActivity
                          ? Icon(Icons.check, size: 17, color: scheme.onPrimary)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small figure tile — icon, value, caption.
class RewardStatTile extends StatelessWidget {
  const RewardStatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = tint ?? scheme.primary;
    return HomeCard(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.md,
        horizontal: Insets.sm,
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(height: Insets.xs + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One badge in a list: icon, name, what it takes, and — for the countable
/// ones — how far along the user is.
class AchievementRow extends StatelessWidget {
  const AchievementRow({
    required this.badge,
    required this.progress,
    this.showProgressBar = true,
    super.key,
  });

  final Badge badge;
  final BadgeProgress progress;
  final bool showProgressBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlocked = progress.unlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? badgeIconForCode(badge.iconCode) : Icons.lock_outline,
              size: 22,
              color: unlocked
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Insets.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        badge.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: unlocked
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: scheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked ? badge.description : badge.criteriaDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                if (showProgressBar &&
                    !unlocked &&
                    progress.isCountable) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.fraction,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${progress.current}/${progress.target}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Weeks of logging activity as a grid of day cells, oldest week at the top.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({required this.weeks, super.key});

  final List<List<ActivityDay>> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = DateFormat.EEEE().dateSymbols.NARROWWEEKDAYS;

    Color cellColor(ActivityDay day) {
      if (day.isFuture) return scheme.surfaceContainer.withValues(alpha: 0.5);
      if (!day.hasActivity) return scheme.surfaceContainerHigh;
      final steps = <double>[0.35, 0.55, 0.75, 1.0];
      final i = (day.transactionCount - 1).clamp(0, steps.length - 1);
      return scheme.primary.withValues(alpha: steps[i]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final cell = ((constraints.maxWidth - gap * 6) / 7).clamp(14.0, 40.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (var d = 1; d <= 7; d++)
                  SizedBox(
                    width: cell,
                    child: Text(
                      initials[d % 7],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: gap),
            for (final week in weeks) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final day in week)
                    Tooltip(
                      message:
                          '${DateFormat('d MMM').format(day.date)}: '
                          '${day.transactionCount} logged',
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: cellColor(day),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
              if (week != weeks.last) const SizedBox(height: gap),
            ],
            const SizedBox(height: Insets.sm + 2),
            Row(
              children: <Widget>[
                Text(
                  'Less',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: Insets.xs + 2),
                for (final a in <double?>[null, 0.35, 0.55, 0.75, 1.0]) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: a == null
                          ? scheme.surfaceContainerHigh
                          : scheme.primary.withValues(alpha: a),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                const SizedBox(width: Insets.xs),
                Text(
                  'More',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/badge_catalogue.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/services/badge_progress.dart';
import '../providers/gamification_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/rewards/rewards_widgets.dart';

/// Which slice of the catalogue the list is showing.
enum _Filter { all, inProgress, completed }

/// The full badge catalogue with progress against each one.
///
/// Badges carry no XP value and no unlock timestamp in this app's data model,
/// so this screen shows neither — only what a badge takes, and how far the
/// user has come towards it.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  _Filter _filter = _Filter.all;
  BadgeGroup? _group;

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(gamificationStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Achievements',
              subtitle: 'Earned by budgeting, not by browsing',
            ),
            Expanded(
              child: stateAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: "Couldn't load your achievements.",
                  detail: e,
                  onRetry: () => ref.invalidate(gamificationStateProvider),
                ),
                data: _buildList,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(GamificationState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlockedCount = state.unlockedBadgeIds
        .where((id) => badgeById(id) != null)
        .length;

    final rows = <(Badge, BadgeProgress)>[
      for (final badge in kBadgeCatalogue)
        (badge, badgeProgressFor(state, badge.id)),
    ];

    final visible = rows
        .where((r) {
          final matchesFilter = switch (_filter) {
            _Filter.all => true,
            _Filter.inProgress => !r.$2.unlocked,
            _Filter.completed => r.$2.unlocked,
          };
          final matchesGroup =
              _group == null || badgeGroupFor(r.$1.id) == _group;
          return matchesFilter && matchesGroup;
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
      children: <Widget>[
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Your Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$unlockedCount / ${kBadgeCatalogue.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: unlockedCount / kBadgeCatalogue.length,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        PillTabs<_Filter>(
          values: _Filter.values,
          labelOf: (f) => switch (f) {
            _Filter.all => 'All',
            _Filter.inProgress => 'In Progress',
            _Filter.completed => 'Completed',
          },
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: Insets.md - 2),
        FilterChips<BadgeGroup?>(
          values: <BadgeGroup?>[null, ...BadgeGroup.values],
          labelOf: (g) => g?.label ?? 'Everything',
          selected: _group,
          onChanged: (g) => setState(() => _group = g),
        ),
        const SizedBox(height: Insets.md - 2),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xl),
            child: Text(
              _filter == _Filter.completed
                  ? 'Nothing unlocked in this group yet.'
                  : 'Everything in this group is done.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          HomeCard(
            child: Column(
              children: <Widget>[
                for (final (badge, progress) in visible)
                  AchievementRow(badge: badge, progress: progress),
              ],
            ),
          ),
      ],
    );
  }
}

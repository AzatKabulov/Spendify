import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/gamification_state.dart';
import '../providers/gamification_providers.dart';
import '../providers/rewards_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/reports/report_widgets.dart';
import '../widgets/rewards/rewards_widgets.dart';

/// "Your Stats" — activity over time, from the cached daily aggregates plus
/// the lifetime counters already on `GamificationState`.
///
/// Every figure here is one the app stores or can derive. Where there is no
/// baseline to compare against (All Time, or an empty previous window) the
/// comparison is simply left off rather than shown as 0%.
class YourStatsScreen extends ConsumerWidget {
  const YourStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final activity = ref.watch(rangeActivityProvider);
    final heatmap = ref.watch(activityHeatmapProvider);
    final state = ref.watch(gamificationStateProvider).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Your Stats',
              subtitle: 'How your logging habit is going',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  PillTabs<StatsRange>(
                    values: StatsRange.values,
                    labelOf: (r) => r.label,
                    selected: range,
                    onChanged: ref.read(statsRangeProvider.notifier).set,
                    scrollable: true,
                  ),
                  const SizedBox(height: Insets.md),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _CountCard(
                            label: 'Transactions',
                            value: '${activity.transactionCount}',
                            change: activity.transactionChange,
                            caption: range.comparisonLabel,
                          ),
                        ),
                        const SizedBox(width: Insets.sm + 2),
                        Expanded(
                          child: _CountCard(
                            label: 'Active days',
                            value: '${activity.activeDays}',
                            caption: 'days with something logged',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md - 2),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: FigureCard(
                            label: 'Spent',
                            amountMinor: activity.expenseMinor,
                          ),
                        ),
                        const SizedBox(width: Insets.sm + 2),
                        Expanded(
                          child: FigureCard(
                            label: 'Received',
                            amountMinor: activity.incomeMinor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md - 2),
                  HomeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Logging activity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'The last $kHeatmapWeeks weeks, whichever range is '
                          'selected above.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        ActivityHeatmap(weeks: heatmap),
                      ],
                    ),
                  ),
                  if (state != null) ...<Widget>[
                    const SizedBox(height: Insets.md - 2),
                    _LifetimeCard(state: state),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain count with an optional change pill — the money equivalent is
/// [FigureCard], which formats minor units instead.
class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    this.change,
    this.caption,
  });

  final String label;
  final String value;
  final double? change;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Row(
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (change != null) ...<Widget>[
                const SizedBox(width: Insets.sm),
                DeltaPill(change: change),
              ],
            ],
          ),
          if (caption != null)
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The lifetime counters the gamification engine keeps. These never decrease
/// for deletions the way XP can, so they are labelled "all time".
class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget line(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm - 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: Insets.sm + 2),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'All time',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Insets.sm),
          line(
            Icons.receipt_long_outlined,
            'Transactions logged',
            '${state.transactionsLogged}',
          ),
          line(
            Icons.document_scanner_outlined,
            'Added from a receipt scan',
            '${state.scannedTransactionsLogged}',
          ),
          line(
            Icons.savings_outlined,
            'Budgets created',
            '${state.budgetsCreated}',
          ),
          line(
            Icons.verified_outlined,
            'Budget periods kept',
            '${state.budgetPeriodsWithinLimit}',
          ),
          line(
            Icons.local_fire_department_outlined,
            'Longest streak',
            state.longestStreak == 1 ? '1 day' : '${state.longestStreak} days',
          ),
        ],
      ),
    );
  }
}

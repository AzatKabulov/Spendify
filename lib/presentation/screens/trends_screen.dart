import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../providers/advice_providers.dart';
import '../providers/category_providers.dart';
import '../providers/home_providers.dart';
import '../providers/report_providers.dart';
import '../providers/report_trend_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/reports/report_widgets.dart';
import 'advice_screen.dart';
import 'budgets_screen.dart';
import 'reports_screen.dart';

enum _TrendTab { spending, incomeVsExpense, insights }

/// Trends over the last few periods, plus insights.
///
/// Two kinds of insight live here and are labelled differently on purpose:
/// the "What your numbers show" cards are computed on-device from the user's
/// own aggregates, and the Insights tab holds the Gemini-generated advice —
/// only that one carries the Gemini attribution, because only that one comes
/// from Gemini (CLAUDE.md §7).
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  _TrendTab _tab = _TrendTab.spending;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(reportSelectionProvider);
    final points = ref.watch(trailingPeriodsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Trends & Insights',
              subtitle: 'Discover patterns and improve your habits',
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
                  PeriodChip(
                    label:
                        'Last $kTrendPeriodCount · '
                        '${reportPeriodLabel(selection)}',
                    onTap: () => showPeriodPicker(context, ref),
                  ),
                  const SizedBox(height: Insets.md),
                  PillTabs<_TrendTab>(
                    values: _TrendTab.values,
                    labelOf: (t) => switch (t) {
                      _TrendTab.spending => 'Spending',
                      _TrendTab.incomeVsExpense => 'In vs Out',
                      _TrendTab.insights => 'Insights',
                    },
                    selected: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: Insets.md),
                  if (_tab == _TrendTab.insights)
                    const _AiInsights()
                  else ...<Widget>[
                    HomeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tab == _TrendTab.spending
                                ? 'Spending over time'
                                : 'Income vs expense',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          TrendLines(
                            points: points,
                            showIncome: _tab == _TrendTab.incomeVsExpense,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md - 2),
                    const _ComputedInsights(),
                    const SizedBox(height: Insets.md - 2),
                    const _ActionCard(),
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

/// Observations derived on-device from the user's own aggregates. No AI, and
/// deliberately not labelled as AI.
class _ComputedInsights extends ConsumerWidget {
  const _ComputedInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(periodComparisonProvider);
    final data = ref.watch(reportDataProvider);
    final weekend = ref.watch(weekendSplitProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cards = <Widget>[];

    final change = comparison.expenseChange;
    if (change != null && change.abs() >= 0.01) {
      final down = change < 0;
      cards.add(
        _InsightCard(
          icon: down ? Icons.trending_down : Icons.trending_up,
          tint: down ? scheme.income : scheme.warning,
          title: down ? "You're spending less" : 'Spending is up',
          body:
              'Your spending ${down ? 'fell' : 'rose'} by '
              '${(change.abs() * 100).round()}% compared with '
              '${comparison.previousLabel}.',
        ),
      );
    }

    if (data.byCategory.isNotEmpty) {
      final top = data.byCategory.first;
      final name = categoriesById[top.categoryId]?.name ?? 'One category';
      cards.add(
        _InsightCard(
          icon: Icons.lightbulb_outline,
          tint: scheme.tertiary,
          title: '$name is your biggest category',
          body:
              'It is ${(top.fractionOfExpense * 100).round()}% of what you '
              'spent — ${formatMinor(top.expenseMinor)}.',
        ),
      );
    }

    final uplift = weekend.weekendUplift;
    if (uplift != null && uplift.abs() >= 0.15) {
      final more = uplift > 0;
      cards.add(
        _InsightCard(
          icon: Icons.calendar_today_outlined,
          tint: scheme.primary,
          title: more ? 'Weekends cost you more' : 'Weekdays cost you more',
          body:
              'You spend about ${(uplift.abs() * 100).round()}% '
              '${more ? 'more' : 'less'} per day at weekends '
              '(${formatMinor(weekend.weekendAverageMinor)} vs '
              '${formatMinor(weekend.weekdayAverageMinor)} on weekdays).',
        ),
      );
    }

    if (cards.isEmpty) {
      return HomeCard(
        child: Text(
          'Once there are a couple of periods of history, patterns in your '
          'own numbers will show up here.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'What your numbers show',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'From your own data',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final card in cards) ...<Widget>[
          card,
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

/// The Gemini-generated advice, shown from the on-device cache only.
class _AiInsights extends ConsumerWidget {
  const _AiInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(adviceConfiguredProvider);
    final cached = ref.watch(cachedAdviceProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!configured) {
      return HomeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AI insights are off',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Everything else in Reports works without it. You can turn AI '
              'features on in Settings → AI Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Key Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
              const SizedBox(width: Insets.xs),
              Text(
                'Powered by Google Gemini',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        cached.when(
          loading: () =>
              const HomeCard(child: Center(child: CircularProgressIndicator())),
          error: (_, _) => HomeCard(
            child: Text(
              "Couldn't read your saved insights.",
              style: theme.textTheme.bodyMedium,
            ),
          ),
          data: (advice) {
            if (advice == null) {
              return HomeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No insights generated yet',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Open Insights to generate advice from an aggregated '
                      'summary of your spending.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdviceScreen(),
                        ),
                      ),
                      child: const Text('Open Insights'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final item in advice.items) ...<Widget>[
                  _InsightCard(
                    icon: Icons.auto_awesome,
                    tint: scheme.primary,
                    title: item.title,
                    body: item.body,
                  ),
                  const SizedBox(height: Insets.sm),
                ],
                Text(
                  'Generated '
                  '${DateFormat('d MMM, HH:mm').format(advice.generatedAt.toLocal())}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdviceScreen(),
                    ),
                  ),
                  child: const Text('Open Insights'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: tint.withValues(alpha: 0.14),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: Insets.sm + Insets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BudgetsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Icon(Icons.eco_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: Insets.sm + Insets.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Turn insights into action',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Set a budget, track your progress, reach your goals.',
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
      ),
    );
  }
}

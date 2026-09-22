import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/advice_item.dart';
import '../../domain/entities/category.dart';
import '../providers/advice_detail_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/advice/advice_widgets.dart';
import '../widgets/category_avatar.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/reports/report_widgets.dart';

/// A tapped insight, in more depth — generalises the mockup's bespoke
/// "spending decreased" drill-in to any [AdviceItem].
///
/// Nothing here is a second Gemini call: the "numbers behind this" section is
/// computed on-device from the cached monthly aggregates (CLAUDE.md §6 — no
/// transaction scan), and "Gemini's take" simply re-shows the same item's own
/// text, so nothing is claimed here that wasn't already generated.
///
/// **Deliberately omitted:** a "Positive/Attention" sentiment badge. The
/// mockup shows one, but nothing in the data honestly classifies an arbitrary
/// piece of free-text advice as good or bad news — guessing from keywords
/// would risk mislabelling it, so it is left off rather than faked.
class AdviceDetailScreen extends ConsumerWidget {
  const AdviceDetailScreen({required this.item, super.key});

  final AdviceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(adviceMonthComparisonProvider);
    final changes = ref.watch(adviceCategoryChangesProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final last = points.isNotEmpty ? points.first : null;
    final current = points.length > 1 ? points[1] : null;
    final expenseChange =
        (last != null && current != null && last.expenseMinor > 0)
        ? (current.expenseMinor - last.expenseMinor) / last.expenseMinor
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(title: 'Insight'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  InsightCard(item: item),
                  const SizedBox(height: Insets.md),
                  if (current != null && last != null) ...<Widget>[
                    HomeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'This month vs last',
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
                          const SizedBox(height: Insets.xs),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatMinor(current.expenseMinor),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Insets.sm),
                              DeltaPill(
                                change: expenseChange,
                                goodWhenDown: true,
                              ),
                            ],
                          ),
                          Text(
                            'vs ${formatMinor(last.expenseMinor)} in '
                            '${last.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          TrendBars(points: points),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md - 2),
                  ],
                  if (changes.isNotEmpty) ...<Widget>[
                    HomeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'What changed?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          for (final change in changes.take(5))
                            _CategoryChangeRow(
                              change: change,
                              category: categoriesById[change.categoryId],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md - 2),
                  ],
                  HomeCard(
                    gradient: LinearGradient(
                      colors: <Color>[
                        scheme.primaryContainer.withValues(alpha: 0.7),
                        Colors.white,
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const GeminiMark(),
                        const SizedBox(height: Insets.sm),
                        Text(
                          item.title.isEmpty ? "Gemini's take" : item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(item.body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChangeRow extends StatelessWidget {
  const _CategoryChangeRow({required this.change, required this.category});

  final CategoryChange change;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = change.changeFraction;
    final sign = change.deltaMinor < 0 ? '−' : '+';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm - 2),
      child: Row(
        children: <Widget>[
          CategoryAvatar(category: category, radius: 16),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorised',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$sign${formatMinor(change.deltaMinor.abs())}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (fraction == null)
                Text(
                  'new this month',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                DeltaPill(change: fraction, goodWhenDown: true),
            ],
          ),
        ],
      ),
    );
  }
}

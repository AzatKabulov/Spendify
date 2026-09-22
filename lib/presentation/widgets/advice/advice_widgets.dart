import 'package:flutter/material.dart';

import '../../../core/theme/insets.dart';
import '../../../domain/entities/advice_item.dart';
import '../home/home_sections.dart';

/// Building blocks shared by the Insights / Insight detail / Ask Spendify AI
/// screens. Presentational only.

/// A representative icon + label per [AdviceItemType] — one per *category*,
/// not a bespoke pictogram per exact suggestion (Gemini classifies each item
/// into one of three buckets; it doesn't also pick an icon).
extension AdviceItemTypeUi on AdviceItemType {
  IconData get icon => switch (this) {
    AdviceItemType.spending => Icons.insights_outlined,
    AdviceItemType.saving => Icons.savings_outlined,
    AdviceItemType.budgeting => Icons.track_changes_outlined,
    AdviceItemType.general => Icons.lightbulb_outline,
  };

  String get label => switch (this) {
    AdviceItemType.spending => 'Spending',
    AdviceItemType.saving => 'Saving',
    AdviceItemType.budgeting => 'Budgeting',
    AdviceItemType.general => 'General',
  };
}

/// One suggestion, tappable through to [AdviceDetailScreen] when [onTap] is
/// given.
class InsightCard extends StatelessWidget {
  const InsightCard({required this.item, this.onTap, super.key});

  final AdviceItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              item.type.icon,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Insets.sm + Insets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title.isEmpty ? item.type.label : item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// The small "Powered by Google Gemini" mark. Only ever placed next to
/// content that genuinely came from Gemini (CLAUDE.md §7 — labelling
/// anything else this way would be misleading).
class GeminiMark extends StatelessWidget {
  const GeminiMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 13, color: scheme.onPrimaryContainer),
          const SizedBox(width: Insets.xs),
          Text(
            'Powered by Google Gemini',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact disclaimer that must travel WITH the advice, never buried in
/// Settings (Phase 9 brief / CLAUDE.md §7).
class AdviceDisclaimer extends StatelessWidget {
  const AdviceDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: Insets.xs + 2),
        Expanded(
          child: Text(
            'AI-generated guidance based on your own spending. Not '
            'financial advice.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A centred icon/title/body state — the Insights screen's not-configured /
/// not-enough-data / offline / error states, restyled to the redesign's
/// language (a plain centred block rather than the old boxed banner).
class AdviceStateView extends StatelessWidget {
  const AdviceStateView({
    required this.icon,
    required this.title,
    this.body,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: theme.colorScheme.outline),
            const SizedBox(height: Insets.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

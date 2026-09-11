import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/services/budget_evaluator.dart';

/// Colour + icon + short label for a [BudgetLevel]. Colour is never the only
/// signal — every use pairs it with the icon or the label (accessibility,
/// colour-blind users; CLAUDE.md Phase 12 accessibility pass).
({Color color, IconData icon, String label}) budgetLevelVisual(
  BuildContext context,
  BudgetLevel level,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    BudgetLevel.safe => (
      color: scheme.income,
      icon: Icons.check_circle_outline,
      label: 'On track',
    ),
    BudgetLevel.approaching => (
      color: scheme.warning,
      icon: Icons.warning_amber_rounded,
      label: 'Approaching limit',
    ),
    BudgetLevel.exceeded => (
      color: scheme.error,
      icon: Icons.error_outline,
      label: 'Over budget',
    ),
  };
}

/// A labelled progress bar for a budget. Bar colour follows [BudgetLevel] and
/// is always accompanied by the icon + text row above it.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    required this.status,
    this.showLabel = true,
    super.key,
  });

  final BudgetStatus status;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = budgetLevelVisual(context, status.level);
    final clamped = status.fractionUsed.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                Icon(v.icon, size: 16, color: v.color),
                const SizedBox(width: 4),
                Text(
                  v.label,
                  style: theme.textTheme.labelMedium?.copyWith(color: v.color),
                ),
                const Spacer(),
                Text(
                  '${(status.fractionUsed * 100).round()}%',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped == 0 ? 0.0 : clamped,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(v.color),
          ),
        ),
      ],
    );
  }
}

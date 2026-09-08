import 'package:flutter/material.dart';

import '../../domain/services/budget_evaluator.dart';
import 'budget_visuals.dart';

/// Compact home-screen banner shown when one or more budgets are approaching
/// or over their limit. Tapping it opens the budget list. Colour is paired
/// with an icon and text — never colour alone.
class BudgetWarningBanner extends StatelessWidget {
  const BudgetWarningBanner({
    required this.warnings,
    required this.onTap,
    super.key,
  });

  final List<BudgetStatus> warnings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    final worst = warnings.any((w) => w.isExceeded)
        ? BudgetLevel.exceeded
        : BudgetLevel.approaching;
    final v = budgetLevelVisual(context, worst);
    final exceeded = warnings.where((w) => w.isExceeded).length;

    final String message;
    if (warnings.length == 1) {
      final w = warnings.single;
      final scope = w.budget.isOverall ? 'Overall budget' : 'A category budget';
      message = w.isExceeded
          ? '$scope is over its ${w.budget.period.name} limit'
          : '$scope is approaching its ${w.budget.period.name} limit';
    } else if (exceeded > 0) {
      message =
          '$exceeded budget${exceeded == 1 ? '' : 's'} over limit, '
          '${warnings.length} need attention';
    } else {
      message = '${warnings.length} budgets approaching their limit';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: v.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(v.icon, color: v.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: v.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: v.color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

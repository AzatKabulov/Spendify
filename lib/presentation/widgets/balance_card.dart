import 'package:flutter/material.dart';

import '../../core/utils/money.dart';

/// The balance header on the home screen. Dumb: takes numbers, shows them.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.balanceMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    super.key,
  });

  final int balanceMinor;
  final int incomeMinor;
  final int expenseMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Balance',
              style: theme.textTheme.labelLarge?.copyWith(
                color: onColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMinor(balanceMinor),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _Total(
                  label: 'Income',
                  value: formatMinor(incomeMinor),
                  color: onColor,
                ),
                const SizedBox(width: 24),
                _Total(
                  label: 'Expenses',
                  value: formatMinor(expenseMinor),
                  color: onColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

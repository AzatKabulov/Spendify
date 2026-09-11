import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';

/// Income / expense / net for the viewed report period.
class ReportSummaryHeader extends StatelessWidget {
  const ReportSummaryHeader({
    required this.incomeMinor,
    required this.expenseMinor,
    super.key,
  });

  final int incomeMinor;
  final int expenseMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = incomeMinor - expenseMinor;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _cell(
                  context,
                  'Income',
                  formatMinor(incomeMinor),
                  theme.colorScheme.income,
                ),
                _cell(
                  context,
                  'Expenses',
                  formatMinor(expenseMinor),
                  theme.colorScheme.expense,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Net', style: theme.textTheme.titleMedium),
                Text(
                  formatMinorSigned(net),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: net >= 0
                        ? theme.colorScheme.income
                        : theme.colorScheme.error,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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

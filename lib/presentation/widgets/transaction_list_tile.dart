import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/transaction.dart';
import 'category_avatar.dart';

/// One row in the transaction list. Presentational only — it is handed the
/// already-resolved [category] and calls back for taps.
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    required this.transaction,
    required this.category,
    this.onTap,
    this.categoryOverBudget = false,
    super.key,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback? onTap;

  /// When true, a quiet indicator shows that this transaction's category is
  /// currently over its budget (informational only — see Phase 3 Part D).
  final bool categoryOverBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome
        ? const Color(0xFF2E7D32)
        : theme.colorScheme.onSurface;
    final note = transaction.note;

    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(category: category),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              category?.name ?? 'Uncategorised',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (categoryOverBudget) ...<Widget>[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Category is over budget',
              child: Icon(
                Icons.error_outline,
                size: 15,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        note == null || note.isEmpty
            ? DateFormat('d MMM yyyy').format(transaction.date)
            : '${DateFormat('d MMM').format(transaction.date)} · $note',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isIncome ? '+' : '−'} ${formatMinor(transaction.amountMinor)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';

/// Soft-deletes [transaction] with an UNDO snackbar. [onHide] runs first so a
/// swiped row vanishes immediately (before the stream catches up); [onUnhide]
/// runs if the user undoes.
void deleteTransactionWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required Transaction transaction,
  required VoidCallback onHide,
  required VoidCallback onUnhide,
}) {
  final messenger = ScaffoldMessenger.of(context);
  onHide();
  ref.read(transactionActionsProvider).delete(transaction.id);

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Transaction deleted'),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          onUnhide();
          ref.read(transactionActionsProvider).restore(transaction.id);
        },
      ),
    ),
  );
}

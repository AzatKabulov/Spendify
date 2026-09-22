import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/empty_transactions_view.dart';
import '../widgets/error_view.dart';
import '../widgets/tactile_press.dart';
import '../widgets/transaction_delete.dart';
import '../widgets/transaction_list_tile.dart';
import 'transaction_form_screen.dart';

/// Every transaction, newest first. Swipe a row to delete (with undo); tap to
/// edit. This is the full list that the Home dashboard's "Recent" card links to.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final Set<String> _hiddenIds = <String>{};

  Future<void> _open({Transaction? existing}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionFormScreen(existing: existing),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final overBudget = ref.watch(overBudgetCategoryIdsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: TactilePress(
        child: FloatingActionButton(
          heroTag: 'add-transaction-tab',
          tooltip: 'Add transaction',
          onPressed: _open,
          child: const Icon(Icons.add),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorView(
          message: "Couldn't load your transactions.",
          detail: e,
          onRetry: () => ref.invalidate(transactionsProvider),
        ),
        data: (all) {
          final visible = all
              .where((t) => !_hiddenIds.contains(t.id))
              .toList(growable: false);
          if (visible.isEmpty) return const EmptyTransactionsView();
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final txn = visible[index];
              return Dismissible(
                key: ValueKey<String>(txn.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: scheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.delete_outline,
                    color: scheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) => deleteTransactionWithUndo(
                  context: context,
                  ref: ref,
                  transaction: txn,
                  onHide: () => setState(() => _hiddenIds.add(txn.id)),
                  onUnhide: () => setState(() => _hiddenIds.remove(txn.id)),
                ),
                child: TransactionListTile(
                  transaction: txn,
                  category: categoriesById[txn.categoryId],
                  categoryOverBudget: overBudget.contains(txn.categoryId),
                  onTap: () => _open(existing: txn),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

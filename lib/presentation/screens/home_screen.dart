import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/receipt_scan_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_warning_banner.dart';
import '../widgets/empty_transactions_view.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/transaction_list_tile.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'receipt_scan_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_form_screen.dart';

/// The app's home: balance header + budget warnings + recent transactions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Ids dismissed from the list but not yet gone from the stream, so a
  /// swiped row disappears immediately and cleanly.
  final Set<String> _hiddenIds = <String>{};

  Future<void> _push(Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openAddForm() => _push(const TransactionFormScreen());

  Future<void> _openEditForm(Transaction transaction) =>
      _push(TransactionFormScreen(existing: transaction));

  void _deleteWithUndo(Transaction transaction) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiddenIds.add(transaction.id));
    ref.read(transactionActionsProvider).delete(transaction.id);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() => _hiddenIds.remove(transaction.id));
            ref.read(transactionActionsProvider).restore(transaction.id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final balanceMinor = ref.watch(currentBalanceMinorProvider);
    final totals = ref.watch(currentTotalsProvider);
    final warnings = ref.watch(budgetWarningsProvider);
    final overBudgetCategories = ref.watch(overBudgetCategoryIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spendly'),
        actions: <Widget>[
          const SyncStatusIndicator(),
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => _push(const ReportsScreen()),
          ),
          IconButton(
            tooltip: 'Budgets',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => _push(const BudgetsScreen()),
          ),
          PopupMenuButton<int>(
            onSelected: (choice) => _push(
              choice == 0 ? const CategoriesScreen() : const SettingsScreen(),
            ),
            itemBuilder: (context) => const <PopupMenuEntry<int>>[
              PopupMenuItem<int>(value: 0, child: Text('Categories')),
              PopupMenuItem<int>(value: 1, child: Text('Settings')),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (ref.watch(receiptScanConfiguredProvider))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'scan',
                tooltip: 'Scan receipt',
                onPressed: () => _push(const ReceiptScanScreen()),
                child: const Icon(Icons.document_scanner_outlined),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _openAddForm,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          BalanceCard(
            balanceMinor: balanceMinor,
            incomeMinor: totals.incomeMinor,
            expenseMinor: totals.expenseMinor,
          ),
          BudgetWarningBanner(
            warnings: warnings,
            onTap: () => _push(const BudgetsScreen()),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('Could not load: $e')),
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
                      background: _swipeBackground(context),
                      onDismissed: (_) => _deleteWithUndo(txn),
                      child: TransactionListTile(
                        transaction: txn,
                        category: categoriesById[txn.categoryId],
                        categoryOverBudget: overBudgetCategories.contains(
                          txn.categoryId,
                        ),
                        onTap: () => _openEditForm(txn),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackground(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

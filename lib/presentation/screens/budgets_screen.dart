import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/budget.dart';
import '../../domain/services/budget_evaluator.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/budget_visuals.dart';
import '../widgets/error_view.dart';
import 'budget_form_screen.dart';

/// List / create / edit / delete budgets, each with live spend for its period.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _openForm(BuildContext context, {Budget? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BudgetFormScreen(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final statuses = ref.watch(budgetStatusesProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);

    BudgetStatus? statusFor(String id) {
      for (final s in statuses) {
        if (s.budget.id == id) return s;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: budgetsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorView(
          message: "Couldn't load your budgets.",
          detail: e,
          onRetry: () => ref.invalidate(budgetsProvider),
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return const _NoBudgets();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final scopeName = budget.isOverall
                  ? 'Overall'
                  : categoriesById[budget.categoryId]?.name ?? 'Unknown';
              return Dismissible(
                key: ValueKey<String>(budget.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) {
                  ref.read(budgetActionsProvider).delete(budget.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$scopeName budget deleted')),
                  );
                },
                child: _BudgetCard(
                  budget: budget,
                  scopeName: scopeName,
                  status: statusFor(budget.id),
                  onTap: () => _openForm(context, existing: budget),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.scopeName,
    required this.status,
    required this.onTap,
  });

  final Budget budget;
  final String scopeName;
  final BudgetStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      scopeName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    budget.period.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s == null
                    ? 'Limit ${formatMinor(budget.limitAmountMinor)}'
                    : '${formatMinor(s.spentMinor)} of '
                          '${formatMinor(s.limitMinor)} spent',
                style: theme.textTheme.bodyMedium,
              ),
              if (s != null) ...<Widget>[
                const SizedBox(height: 10),
                BudgetProgressBar(status: s),
                const SizedBox(height: 6),
                Text(
                  s.remainingMinor >= 0
                      ? '${formatMinor(s.remainingMinor)} left'
                      : '${formatMinor(-s.remainingMinor)} over',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: s.remainingMinor >= 0
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoBudgets extends StatelessWidget {
  const _NoBudgets();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No budgets yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Set a weekly or monthly limit — overall or per category — and '
              'Spendify will warn you as you approach it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

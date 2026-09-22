import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/budget_evaluator.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/repository_providers.dart';
import '../widgets/auth/auth_illustrations.dart';
import '../widgets/budget_visuals.dart';
import '../widgets/category_avatar.dart';
import '../widgets/error_view.dart';
import '../widgets/tactile_press.dart';
import 'budget_form_screen.dart';

/// List / create / edit / delete budgets, each with live spend for its
/// period. A top-level tab (reached from Home's bottom navigation), so —
/// unlike the create/edit forms — it has no back button; the "+" moved from
/// a bottom FAB into the header to match the approved mockup.
///
/// The mockup's period tabs are "Monthly / Weekly / Yearly", but a budget's
/// own period is only ever weekly or monthly (CLAUDE.md §4 — there is no
/// yearly budget period), so a fake "Yearly" tab is left out here.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  BudgetPeriod _period = BudgetPeriod.monthly;

  Future<void> _openForm(BuildContext context, {Budget? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BudgetFormScreen(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final statuses = ref.watch(budgetStatusesProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final now = ref.watch(localTimeProvider)();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    BudgetStatus? statusFor(String id) {
      for (final s in statuses) {
        if (s.budget.id == id) return s;
      }
      return null;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                Insets.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Budgets',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Stay on track with your goals',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TactilePress(
                    child: FloatingActionButton.small(
                      heroTag: 'new-budget',
                      tooltip: 'New budget',
                      onPressed: () => _openForm(context),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: _PeriodToggle(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
            ),
            Expanded(
              child: budgetsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorView(
                  message: "Couldn't load your budgets.",
                  detail: e,
                  onRetry: () => ref.invalidate(budgetsProvider),
                ),
                data: (budgets) {
                  final inPeriod = budgets
                      .where((b) => b.period == _period)
                      .toList(growable: false);
                  BudgetStatus? overall;
                  for (final b in inPeriod) {
                    if (b.isOverall) {
                      overall = statusFor(b.id);
                      break;
                    }
                  }
                  final byCategory = inPeriod
                      .where((b) => !b.isOverall)
                      .toList(growable: false);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.sm,
                      Insets.md,
                      Insets.lg,
                    ),
                    children: <Widget>[
                      Text(
                        DateFormat(
                          _period == BudgetPeriod.monthly
                              ? 'MMMM yyyy'
                              : "'Week of' d MMM",
                        ).format(now),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      if (overall == null)
                        _NoOverallBudget(
                          period: _period,
                          onCreate: () => _openForm(context),
                        )
                      else
                        _OverallCard(
                          status: overall,
                          onTap: () =>
                              _openForm(context, existing: overall!.budget),
                        ),
                      const SizedBox(height: Insets.lg),
                      Row(
                        children: <Widget>[
                          Text(
                            'Category Budgets',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (byCategory.isNotEmpty)
                            TextButton(
                              onPressed: () => _openForm(context),
                              child: const Text('See all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      if (byCategory.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Insets.sm,
                          ),
                          child: Text(
                            'No category budgets for this period yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (final b in byCategory)
                          Dismissible(
                            key: ValueKey<String>(b.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: scheme.errorContainer,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline),
                            ),
                            onDismissed: (_) {
                              final name =
                                  categoriesById[b.categoryId]?.name ??
                                  'Unknown';
                              ref.read(budgetActionsProvider).delete(b.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$name budget deleted')),
                              );
                            },
                            child: _CategoryBudgetRow(
                              category: categoriesById[b.categoryId],
                              status: statusFor(b.id),
                              onTap: () => _openForm(context, existing: b),
                            ),
                          ),
                      const SizedBox(height: Insets.md),
                      _TipRow(onTap: () => _openForm(context)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final BudgetPeriod value;
  final ValueChanged<BudgetPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(BudgetPeriod period, String label) {
      final selected = value == period;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(period),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm + 2),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          segment(BudgetPeriod.monthly, 'Monthly'),
          segment(BudgetPeriod.weekly, 'Weekly'),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = budgetLevelVisual(context, status.level);
    final fraction = status.fractionUsed.clamp(0.0, 1.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      // Always a concrete value, never `null` — `null` means
                      // "indeterminate", an endlessly-animating spinner,
                      // which is wrong for "0% spent so far" and never lets
                      // a widget test's pumpAndSettle finish.
                      value: fraction,
                      strokeWidth: 7,
                      color: v.color,
                      backgroundColor: scheme.outlineVariant,
                    ),
                    Padding(
                      // Keeps the two-line label off the ring's own stroke,
                      // and FittedBox guarantees it never overflows the
                      // ring regardless of the device's text-scale setting.
                      padding: const EdgeInsets.all(22),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${(status.fractionUsed * 100).round()}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'of budget',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Overall',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${formatMinor(status.spentMinor)} spent of '
                      '${formatMinor(status.limitMinor)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      status.remainingMinor >= 0
                          ? '${formatMinor(status.remainingMinor)} remaining'
                          : '${formatMinor(-status.remainingMinor)} over',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: v.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoOverallBudget extends StatelessWidget {
  const _NoOverallBudget({required this.period, required this.onCreate});

  final BudgetPeriod period;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onCreate,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_outlined,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'No overall ${period.name} budget yet — tap to set one.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.status,
    required this.onTap,
  });

  final Category? category;
  final BudgetStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = status;
    final v = s == null ? null : budgetLevelVisual(context, s.level);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                CategoryAvatar(category: category, radius: 20),
                const SizedBox(width: Insets.sm + Insets.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category?.name ?? 'Unknown',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (s != null) ...<Widget>[
                        const SizedBox(height: Insets.xs),
                        Text(
                          '${formatMinor(s.spentMinor)} / '
                          '${formatMinor(s.limitMinor)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Insets.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: s.fractionUsed.clamp(0.0, 1.0),
                            minHeight: 6,
                            color: v!.color,
                            backgroundColor: scheme.outlineVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (s != null) ...<Widget>[
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${(s.fractionUsed * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: v!.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              const LeafMark(size: 22),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Set a budget, build a better you',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Small limits. Bigger freedom.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

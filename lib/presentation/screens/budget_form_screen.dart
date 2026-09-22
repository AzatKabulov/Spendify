import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/budget_evaluator.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/repository_providers.dart';
import '../widgets/budget_visuals.dart';
import '../../domain/entities/category.dart';
import '../widgets/category_avatar.dart';
import '../widgets/form_header.dart';
import '../widgets/tactile_press.dart';

/// Sentinel value for the "Overall" option in the scope picker, since a
/// null category id can't be distinguished from "unselected".
const String _overallScope = '__overall__';

/// Create (when [existing] is null) or edit a budget.
///
/// The mockup's separate "Repeat" and "End date" fields aren't here: `Budget`
/// already has one recurrence field (`period` — weekly or monthly, CLAUDE.md
/// §4) and no end date, so a second "repeat" control would just restate the
/// period picker, and an end date would be a new persisted field this task
/// didn't ask for. There is also no "notify me at 80%" toggle — the app has
/// no push-notification capability; the in-app warning banner is what
/// actually does this job today.
class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({this.existing, super.key});

  final Budget? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

const List<int> _quickAmountsMinor = <int>[10000, 30000, 70000, 100000];

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;
  final _limitFocus = FocusNode();
  late String _scope; // _overallScope or a categoryId
  late BudgetPeriod _period;
  late DateTime _startDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _limitController = TextEditingController(
      text: b == null ? '' : minorToEditString(b.limitAmountMinor),
    );
    _scope = b?.categoryId ?? _overallScope;
    _period = b?.period ?? BudgetPeriod.monthly;
    _startDate = b?.startDate ?? ref.read(clockProvider)().toLocal();
  }

  @override
  void dispose() {
    _limitController.dispose();
    _limitFocus.dispose();
    super.dispose();
  }

  String? get _selectedCategoryId => _scope == _overallScope ? null : _scope;

  String? _validateLimit(String? raw) {
    final minor = parseAmountToMinor(raw ?? '');
    if (minor == null) return 'Enter a valid amount';
    if (minor <= 0) return 'Limit must be greater than zero';
    return null;
  }

  String? _duplicateError() {
    final existing = ref.read(budgetsProvider).value ?? const <Budget>[];
    if (isBudgetDuplicate(
      existing,
      _selectedCategoryId,
      _period,
      excludingId: widget.existing?.id,
    )) {
      final scopeName = _scope == _overallScope
          ? 'the overall'
          : 'this category\'s';
      return 'There is already $scopeName ${_period.name} budget.';
    }
    return null;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(_startDate.year - 5),
      lastDate: DateTime(_startDate.year + 5),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dup = _duplicateError();
    if (dup != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dup)));
      return;
    }

    setState(() => _saving = true);
    final actions = ref.read(budgetActionsProvider);
    final limit = parseAmountToMinor(_limitController.text)!;
    try {
      if (widget.existing case final existing?) {
        await actions.edit(
          existing,
          categoryId: _selectedCategoryId,
          limitAmountMinor: limit,
          period: _period,
          startDate: _startDate,
        );
      } else {
        await actions.create(
          categoryId: _selectedCategoryId,
          limitAmountMinor: limit,
          period: _period,
          startDate: _startDate,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this budget?'),
        content: const Text('This cannot be undone from here.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(budgetActionsProvider).delete(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // Keep the budget list subscribed so [_duplicateError] sees a live value.
    ref.watch(budgetsProvider);
    final statuses = ref.watch(budgetStatusesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    BudgetStatus? liveStatus;
    final existingId = widget.existing?.id;
    if (existingId != null) {
      for (final s in statuses) {
        if (s.budget.id == existingId) {
          liveStatus = s;
          break;
        }
      }
    }

    Category? scopeCategory;
    if (_selectedCategoryId != null) {
      for (final c in categories) {
        if (c.id == _selectedCategoryId) {
          scopeCategory = c;
          break;
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(
              title: widget.isEditing ? 'Edit Budget' : 'Create Budget',
              subtitle: widget.isEditing
                  ? 'Update your budget settings'
                  : 'Set a limit and stay on track',
              trailing: widget.isEditing
                  ? FormHeaderButton.delete(onPressed: _delete)
                  : null,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.sm,
                    Insets.md,
                    Insets.xl,
                  ),
                  children: <Widget>[
                    Text(
                      'Applies to',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    _ScopePicker(
                      scope: _scope,
                      category: scopeCategory,
                      categories: categories,
                      onChanged: (v) => setState(() => _scope = v),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Budget amount',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    TextFormField(
                      controller: _limitController,
                      focusNode: _limitFocus,
                      autofocus: !widget.isEditing,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Limit',
                        prefixText: 'RM ',
                      ),
                      validator: _validateLimit,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: Insets.sm),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: <Widget>[
                        for (final minor in _quickAmountsMinor)
                          _AmountChip(
                            label: formatMinor(minor),
                            selected:
                                parseAmountToMinor(_limitController.text) ==
                                minor,
                            onTap: () => setState(
                              () => _limitController.text = minorToEditString(
                                minor,
                              ),
                            ),
                          ),
                        _AmountChip(
                          label: 'Custom',
                          selected: !_quickAmountsMinor.contains(
                            parseAmountToMinor(_limitController.text) ?? -1,
                          ),
                          onTap: () => _limitFocus.requestFocus(),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Period',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    _PeriodToggle(
                      value: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Start date',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: const InputDecoration(),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: Insets.sm),
                            Text(
                              DateFormat('d MMM yyyy').format(_startDate),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (liveStatus != null) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      _SpendingThisPeriodCard(
                        status: liveStatus,
                        now: ref.watch(localTimeProvider)(),
                      ),
                    ] else if (!widget.isEditing) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      const _InfoBanner(
                        icon: Icons.eco_outlined,
                        title: 'Build better habits',
                        text:
                            'Budgets help you control your spending and '
                            'reach your financial goals.',
                      ),
                    ],
                    const SizedBox(height: Insets.xl),
                    TactilePress(
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            widget.isEditing ? 'Save Changes' : 'Create',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  const _ScopePicker({
    required this.scope,
    required this.category,
    required this.categories,
    required this.onChanged,
  });

  final String scope;
  final Category? category;
  final List<Category> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOverall = scope == _overallScope;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              isOverall
                  ? CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                  : CategoryAvatar(category: category, radius: 20),
              const SizedBox(width: Insets.sm + Insets.xs),
              Expanded(
                child: Text(
                  isOverall ? 'Overall (all categories)' : category!.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => _openPicker(context),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Overall (all categories)'),
              onTap: () {
                onChanged(_overallScope);
                Navigator.of(sheet).pop();
              },
            ),
            for (final c in categories)
              ListTile(
                leading: CategoryAvatar(category: c, radius: 16),
                title: Text(c.name),
                onTap: () {
                  onChanged(c.id);
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.primary : scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
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

class _SpendingThisPeriodCard extends StatelessWidget {
  const _SpendingThisPeriodCard({required this.status, required this.now});

  final BudgetStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = budgetLevelVisual(context, status.level);
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = status.periodEnd.difference(today).inDays.clamp(0, 366);

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Spending this ${status.budget.period == BudgetPeriod.weekly ? 'week' : 'month'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      formatMinor(status.spentMinor),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'spent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${(status.fractionUsed * 100).round()}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: v.color,
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
            ],
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: status.fractionUsed.clamp(0.0, 1.0),
              minHeight: 8,
              color: v.color,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Row(
            children: <Widget>[
              Text(
                status.remainingMinor >= 0
                    ? '${formatMinor(status.remainingMinor)} remaining'
                    : '${formatMinor(-status.remainingMinor)} over',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (daysLeft > 0)
                Text(
                  '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: scheme.onPrimaryContainer),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(text, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

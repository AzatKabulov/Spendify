import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/enums.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/category_avatar.dart';

/// Sentinel value for the "Overall" option in the scope dropdown, since a
/// null `DropdownMenuItem.value` can't be distinguished from "unselected".
const String _overallScope = '__overall__';

/// Create (when [existing] is null) or edit a budget.
class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({this.existing, super.key});

  final Budget? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;
  late String _scope; // _overallScope or a categoryId
  late BudgetPeriod _period;
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
  }

  @override
  void dispose() {
    _limitController.dispose();
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
        );
      } else {
        await actions.create(
          categoryId: _selectedCategoryId,
          limitAmountMinor: limit,
          period: _period,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // Keep the budget list subscribed so [_duplicateError] sees a live value.
    ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit budget' : 'New budget'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: const InputDecoration(
                  labelText: 'Applies to',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: _overallScope,
                    child: Text('Overall (all categories)'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem<String>(
                      value: c.id,
                      child: Row(
                        children: <Widget>[
                          CategoryAvatar(category: c, radius: 12),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _scope = v ?? _overallScope),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                autofocus: !widget.isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Limit',
                  prefixText: 'RM ',
                  border: OutlineInputBorder(),
                ),
                validator: _validateLimit,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              SegmentedButton<BudgetPeriod>(
                segments: const <ButtonSegment<BudgetPeriod>>[
                  ButtonSegment(
                    value: BudgetPeriod.weekly,
                    label: Text('Weekly'),
                  ),
                  ButtonSegment(
                    value: BudgetPeriod.monthly,
                    label: Text('Monthly'),
                  ),
                ],
                selected: <BudgetPeriod>{_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.isEditing ? 'Save changes' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

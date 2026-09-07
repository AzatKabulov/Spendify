import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/category_avatar.dart';

/// Add (when [existing] is null) or edit a transaction. One widget for both,
/// so the two flows never drift apart.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({this.existing, super.key});

  final Transaction? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : minorToEditString(existing.amountMinor),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _type = existing?.type ?? TransactionType.expense;
    final now = ref.read(clockProvider)().toLocal();
    _date = existing?.date ?? DateTime(now.year, now.month, now.day);
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? raw) {
    final minor = parseAmountToMinor(raw ?? '');
    if (minor == null) {
      return 'Enter a valid amount (up to 2 decimal places)';
    }
    if (minor <= 0) return 'Amount must be greater than zero';
    return null;
  }

  Future<void> _pickDate() async {
    final today = ref.read(clockProvider)().toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 10),
      // Today and past only (Phase 2 spec).
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;

    setState(() => _saving = true);
    final actions = ref.read(transactionActionsProvider);
    final amountMinor = parseAmountToMinor(_amountController.text)!;
    final note = _noteController.text;

    try {
      if (widget.existing case final existing?) {
        await actions.edit(
          existing,
          amountMinor: amountMinor,
          type: _type,
          categoryId: categoryId,
          date: _date,
          note: note,
        );
      } else {
        await actions.create(
          amountMinor: amountMinor,
          type: _type,
          categoryId: categoryId,
          date: _date,
          note: note,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit transaction' : 'Add transaction'),
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load categories: $e')),
          data: (categories) => _form(context, categories),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, List<Category> categories) {
    // Lazily adopt the default category once categories are available. Only
    // fires while `_categoryId` is still unset (fresh add form).
    _categoryId ??=
        ref.watch(defaultNewTransactionCategoryProvider)?.id ??
        (categories.isNotEmpty ? categories.first.id : null);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            controller: _amountController,
            autofocus: !widget.isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: 'RM ',
              border: OutlineInputBorder(),
            ),
            validator: _validateAmount,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TransactionType>(
            segments: const <ButtonSegment<TransactionType>>[
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.south_west),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.north_east),
              ),
            ],
            selected: <TransactionType>{_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
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
            onChanged: (v) => setState(() => _categoryId = v),
            validator: (v) => v == null ? 'Pick a category' : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                widget.isEditing ? 'Save changes' : 'Add transaction',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

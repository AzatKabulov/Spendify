import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';
import '../providers/receipt_scan_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/category_avatar.dart';

/// Add (when [existing] is null) or edit a transaction. One widget for both,
/// so the two flows never drift apart.
///
/// When [prefill] is set the form is seeded from a receipt scan (Phase 7):
/// AI-filled fields are marked, low confidence is flagged, and a save records
/// `source = scanned`. Nothing is ever saved without an explicit tap
/// (CLAUDE.md §7).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({this.existing, this.prefill, super.key});

  final Transaction? existing;
  final ReceiptDraft? prefill;

  bool get isEditing => existing != null;
  bool get isFromScan => prefill != null;

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
    final prefill = widget.prefill;
    final now = ref.read(clockProvider)().toLocal();

    final seededAmount = existing?.amountMinor ?? prefill?.amountMinor;
    _amountController = TextEditingController(
      text: seededAmount == null ? '' : minorToEditString(seededAmount),
    );
    _noteController = TextEditingController(
      text: existing?.note ?? prefill?.note ?? '',
    );
    _type = existing?.type ?? TransactionType.expense;
    _date =
        existing?.date ??
        prefill?.date ??
        DateTime(now.year, now.month, now.day);
    _categoryId = existing?.categoryId ?? prefill?.categoryId;
  }

  bool _aiFilled(ReceiptField field) =>
      widget.prefill?.aiFilled.contains(field) ?? false;

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
          source: widget.isFromScan
              ? TransactionSource.scanned
              : TransactionSource.manual,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _title {
    if (widget.isEditing) return 'Edit transaction';
    if (widget.isFromScan) return 'Check the details';
    return 'Add transaction';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load categories: $e')),
          data: (categories) => _form(context, categories),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, List<Category> pickable) {
    // Lazily adopt the default category once categories are available. Only
    // fires while `_categoryId` is still unset (fresh add form).
    _categoryId ??=
        ref.watch(defaultNewTransactionCategoryProvider)?.id ??
        (pickable.isNotEmpty ? pickable.first.id : null);

    // If editing a transaction whose category was since deleted, keep it in
    // the dropdown (marked) so the field has a matching item and the user can
    // still save without being forced to re-categorise.
    final categories = <Category>[...pickable];
    final currentId = _categoryId;
    if (currentId != null && !categories.any((c) => c.id == currentId)) {
      final deleted = ref.read(categoryDisplayProvider(currentId));
      if (deleted != null) categories.add(deleted);
    }

    final prefill = widget.prefill;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (prefill != null) ...<Widget>[
            _ScanBanner(lowConfidence: prefill.isLowConfidence),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _amountController,
            autofocus: !widget.isEditing && !widget.isFromScan,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'RM ',
              border: const OutlineInputBorder(),
              suffixIcon: _aiFilled(ReceiptField.amount)
                  ? const _FromReceiptMark()
                  : null,
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
            decoration: InputDecoration(
              labelText: 'Category',
              border: const OutlineInputBorder(),
              suffixIcon: _aiFilled(ReceiptField.category)
                  ? const _FromReceiptMark()
                  : null,
              helperText: prefill?.suggestedCategoryUnmatched != null
                  ? 'Receipt said "${prefill!.suggestedCategoryUnmatched}" — '
                        'pick the closest'
                  : null,
            ),
            items: <DropdownMenuItem<String>>[
              for (final c in categories)
                DropdownMenuItem<String>(
                  value: c.id,
                  child: Row(
                    children: <Widget>[
                      CategoryAvatar(category: c, radius: 12),
                      const SizedBox(width: 8),
                      Text(c.isDeleted ? '${c.name} (deleted)' : c.name),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
            validator: (v) => v == null ? 'Pick a category' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                ),
              ),
              if (_aiFilled(ReceiptField.date)) const _FromReceiptMark(),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: _aiFilled(ReceiptField.note)
                  ? const _FromReceiptMark()
                  : null,
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
                widget.isEditing
                    ? 'Save changes'
                    : (widget.isFromScan
                          ? 'Save transaction'
                          : 'Add transaction'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header on the scan-confirmation form. Always tells the user these are
/// AI-extracted values to check; louder when confidence is low.
class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.lowConfidence});

  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = lowConfidence
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final fg = lowConfidence
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            lowConfidence ? Icons.warning_amber_rounded : Icons.auto_awesome,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lowConfidence
                  ? 'The scan was unclear — please check every field before '
                        'saving.'
                  : 'Filled in from your receipt. Check it, then save.',
              style: TextStyle(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// The little "from receipt" marker on an AI-populated field.
class _FromReceiptMark extends StatelessWidget {
  const _FromReceiptMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'From the receipt scan',
      child: Icon(
        Icons.auto_awesome,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

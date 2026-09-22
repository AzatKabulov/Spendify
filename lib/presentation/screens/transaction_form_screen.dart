import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/insets.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_providers.dart';
import '../providers/receipt_scan_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/category_avatar.dart';
import '../widgets/error_view.dart';
import '../widgets/form_header.dart';
import '../widgets/tactile_press.dart';
import 'select_category_screen.dart';

/// Add (when [existing] is null) or edit a transaction. One widget for both,
/// so the two flows never drift apart.
///
/// When [prefill] is set the form is seeded from a receipt scan (Phase 7):
/// AI-filled fields are marked, low confidence is flagged, and a save records
/// `source = scanned`. Nothing is ever saved without an explicit tap
/// (CLAUDE.md §7). There is no "Transfer" type here — the app only models
/// income and expense (CLAUDE.md §4) — and no receipt-thumbnail attachment,
/// since receipt images are never retained after processing (CLAUDE.md §7.5).
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
  late TimeOfDay _time;
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
    final seededDate =
        existing?.date ??
        prefill?.date ??
        DateTime(now.year, now.month, now.day);
    _date = DateTime(seededDate.year, seededDate.month, seededDate.day);
    _time = existing == null
        ? const TimeOfDay(hour: 0, minute: 0)
        : TimeOfDay(hour: seededDate.hour, minute: seededDate.minute);
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickCategory(List<Category> categories) async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SelectCategoryScreen(
          categories: categories,
          selectedId: _categoryId,
        ),
      ),
    );
    if (picked != null) setState(() => _categoryId = picked);
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
    final date = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    try {
      if (widget.existing case final existing?) {
        await actions.edit(
          existing,
          amountMinor: amountMinor,
          type: _type,
          categoryId: categoryId,
          date: date,
          note: note,
        );
      } else {
        await actions.create(
          amountMinor: amountMinor,
          type: _type,
          categoryId: categoryId,
          date: date,
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

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
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
      await ref.read(transactionActionsProvider).delete(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String get _title {
    if (widget.isEditing) return 'Edit Transaction';
    if (widget.isFromScan) return 'Check the details';
    return 'Add Transaction';
  }

  String get _subtitle {
    if (widget.isEditing) return 'Update the details of this transaction';
    if (widget.isFromScan) return 'Confirm what Gemini read from your receipt';
    return 'Record your income or expense';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(
              title: _title,
              subtitle: _subtitle,
              leading: widget.isEditing
                  ? FormHeaderButton.back()
                  : FormHeaderButton.close(),
              trailing: widget.isEditing
                  ? FormHeaderButton.delete(onPressed: _delete)
                  : null,
            ),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: "Couldn't load your categories.",
                  detail: e,
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
                data: (categories) => _form(context, categories),
              ),
            ),
          ],
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
    // the picker (marked) so there is a matching entry.
    final categories = <Category>[...pickable];
    final currentId = _categoryId;
    if (currentId != null && !categories.any((c) => c.id == currentId)) {
      final deleted = ref.read(categoryDisplayProvider(currentId));
      if (deleted != null) categories.add(deleted);
    }

    final prefill = widget.prefill;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.md,
          Insets.md,
          Insets.xl,
        ),
        children: <Widget>[
          if (prefill != null) ...<Widget>[
            _ScanBanner(lowConfidence: prefill.isLowConfidence),
            const SizedBox(height: Insets.md),
          ],
          _TypeToggle(
            value: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Amount',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _amountController,
            autofocus: !widget.isEditing && !widget.isFromScan,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'RM ',
              suffixIcon: _aiFilled(ReceiptField.amount)
                  ? const _FromReceiptMark()
                  : null,
            ),
            validator: _validateAmount,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Text(
                'Category',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_aiFilled(ReceiptField.category)) ...<Widget>[
                const SizedBox(width: Insets.xs),
                const _FromReceiptMark(),
              ],
              const Spacer(),
              InkWell(
                onTap: () => _pickCategory(categories),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xs,
                    vertical: Insets.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'See all',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (prefill?.suggestedCategoryUnmatched != null)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                'Receipt said "${prefill!.suggestedCategoryUnmatched}" — '
                'pick the closest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: Insets.sm),
          // A quick-pick strip, not the primary way to choose a category (that
          // is "See all" -> the full picker) — its text stays legible but is
          // capped so a handful of chips can't need more than one fixed row
          // height, however large the system text setting is.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.3),
            ),
            child: SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
                itemBuilder: (context, index) {
                  final c = categories[index];
                  final selected = c.id == _categoryId;
                  return _CategoryChip(
                    category: c,
                    selected: selected,
                    onTap: () => setState(() => _categoryId = c.id),
                  );
                },
              ),
            ),
          ),
          FormFieldError(
            errorText: _categoryId == null ? 'Pick a category' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Merchant / Description',
              hintText: 'e.g. Grab, McDonald\'s, Grocery',
              prefixIcon: const Icon(Icons.storefront_outlined),
              suffixIcon: _aiFilled(ReceiptField.note)
                  ? const _FromReceiptMark()
                  : null,
            ),
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _PickerField(
                  label: 'Date',
                  icon: Icons.calendar_today_outlined,
                  value: DateFormat('EEE, d MMM yyyy').format(_date),
                  onTap: _pickDate,
                  trailing: _aiFilled(ReceiptField.date)
                      ? const _FromReceiptMark()
                      : null,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                flex: 2,
                child: _PickerField(
                  label: 'Time',
                  icon: Icons.access_time,
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          TactilePress(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  widget.isEditing
                      ? 'Save changes'
                      : (widget.isFromScan
                            ? 'Save transaction'
                            : 'Add transaction'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expense / income pill toggle. Only two — the app has no "transfer" type
/// (CLAUDE.md §4).
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(TransactionType type, String label, IconData icon) {
      final selected = value == type;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(type),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: AppMotion.quick,
            padding: const EdgeInsets.symmetric(vertical: Insets.sm + 2),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
          segment(
            TransactionType.expense,
            'Expense',
            Icons.remove_circle_outline,
          ),
          segment(TransactionType.income, 'Income', Icons.add_circle_outline),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CategoryAvatar(category: category, radius: 18),
            const SizedBox(height: Insets.xs),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            ?trailing,
          ],
        ),
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

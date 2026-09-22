import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_colors.dart';
import '../../core/category_icons.dart';
import '../../core/theme/insets.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_avatar.dart';
import '../widgets/color_picker.dart';
import '../widgets/form_header.dart';
import '../widgets/icon_picker.dart';
import '../widgets/tactile_press.dart';

/// Create (when [existing] is null) or edit a category. Name + icon + colour.
///
/// The mockup's "Description" field and per-category "Total spent" figure
/// aren't here: `Category` has no description in the data model (CLAUDE.md
/// §4), and a lifetime total-spent would mean scanning every transaction for
/// this one category — the report screens deliberately avoid that in favour
/// of the cached aggregates (CLAUDE.md §6). The real, already-computed
/// transaction count is shown instead.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({this.existing, super.key});

  final Category? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _iconCode;
  late int _colorValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameController = TextEditingController(text: c?.name ?? '');
    _iconCode = c?.iconCode ?? kCategoryIcons.first.codePoint;
    _colorValue = c?.colorValue ?? kCategoryColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return 'Enter a name';
    final existing = ref.read(categoriesProvider).value ?? const <Category>[];
    if (isCategoryNameTaken(existing, name, excludingId: widget.existing?.id)) {
      return 'A category called "$name" already exists';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final actions = ref.read(categoryActionsProvider);
    try {
      if (widget.existing case final existing?) {
        await actions.edit(
          existing,
          name: _nameController.text,
          iconCode: _iconCode,
          colorValue: _colorValue,
        );
      } else {
        await actions.create(
          name: _nameController.text,
          iconCode: _iconCode,
          colorValue: _colorValue,
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
    final count = ref.read(categoryTransactionCountProvider(existing.id));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${existing.name}"?'),
        content: Text(
          count == 0
              ? 'This category has no transactions.'
              : 'This category has $count transaction${count == 1 ? '' : 's'}. '
                    'They will be kept and still show this category.',
        ),
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
      await ref.read(categoryActionsProvider).delete(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the category list subscribed so [_validateName] sees a live value.
    ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final existing = widget.existing;

    final preview = Category(
      id: 'preview',
      userId: 'preview',
      name: _nameController.text,
      iconCode: _iconCode,
      colorValue: _colorValue,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(
              title: widget.isEditing ? 'Edit Category' : 'Create Category',
              subtitle: widget.isEditing
                  ? 'Update your category details'
                  : 'Add a category that fits your needs',
              trailing: (widget.isEditing && !(existing?.isDefault ?? true))
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
                    Center(
                      child: CategoryAvatar(category: preview, radius: 30),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Category name',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    TextFormField(
                      controller: _nameController,
                      autofocus: !widget.isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. University, Side Hustle, Gaming',
                      ),
                      validator: _validateName,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Icon',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    IconPicker(
                      selectedCode: _iconCode,
                      onSelected: (c) => setState(() => _iconCode = c),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Colour',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    ColorPicker(
                      selectedValue: _colorValue,
                      onSelected: (v) => setState(() => _colorValue = v),
                    ),
                    if (widget.isEditing &&
                        !(existing?.isDefault ?? true)) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      const _InfoRow(
                        icon: Icons.lightbulb_outline,
                        text:
                            'This is a custom category — it can be edited '
                            'or deleted at any time.',
                      ),
                      const SizedBox(height: Insets.sm),
                      _LinkedTransactionsRow(
                        count: ref.watch(
                          categoryTransactionCountProvider(existing!.id),
                        ),
                      ),
                    ] else if (widget.isEditing) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      const _InfoRow(
                        icon: Icons.lock_outline,
                        text:
                            'This is a default category — its icon, colour '
                            'and name can be changed, but it cannot be '
                            'deleted.',
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
                            widget.isEditing ? 'Save changes' : 'Create',
                          ),
                        ),
                      ),
                    ),
                    if (widget.isEditing &&
                        !(existing?.isDefault ?? true)) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      Center(
                        child: TextButton(
                          onPressed: _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.error,
                          ),
                          child: const Text('Delete Category'),
                        ),
                      ),
                    ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
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
          Icon(icon, color: scheme.onPrimaryContainer, size: 20),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _LinkedTransactionsRow extends StatelessWidget {
  const _LinkedTransactionsRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Linked transactions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$count transaction${count == 1 ? '' : 's'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

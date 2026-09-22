import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/auth/auth_illustrations.dart';
import '../widgets/category_avatar.dart';
import '../widgets/error_view.dart';
import '../widgets/form_header.dart';
import 'category_form_screen.dart';

/// List / create / edit / delete categories ("Manage Categories"). Split
/// into All / Custom tabs, matched to the approved mockup; creating a new
/// category is the "Create Custom Category" row rather than a FAB, since the
/// mockup doesn't use one here.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _customOnly = false;

  Future<void> _openForm(BuildContext context, {Category? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final count = ref.read(categoryTransactionCountProvider(category.id));
    final messenger = ScaffoldMessenger.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
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
    if (proceed ?? false) {
      await ref.read(categoryActionsProvider).delete(category.id);
      messenger.showSnackBar(
        SnackBar(content: Text('"${category.name}" deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Manage Categories',
              subtitle: 'Organise your categories',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                0,
                Insets.md,
                Insets.sm,
              ),
              child: _TabToggle(
                customOnly: _customOnly,
                onChanged: (v) => setState(() => _customOnly = v),
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorView(
                  message: "Couldn't load your categories.",
                  detail: e,
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
                data: (all) {
                  final categories = _customOnly
                      ? all.where((c) => !c.isDefault).toList(growable: false)
                      : all;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      0,
                      Insets.md,
                      Insets.lg,
                    ),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(Insets.md),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            const LeafMark(size: 24),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: Text(
                                'Categories help you organise your spending '
                                'and get better insights.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: <Widget>[
                          Text(
                            _customOnly
                                ? 'Custom Categories'
                                : 'All Categories',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${categories.length} categor'
                            '${categories.length == 1 ? 'y' : 'ies'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.sm),
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Insets.lg,
                          ),
                          child: Text(
                            _customOnly
                                ? 'No custom categories yet.'
                                : 'No categories yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (final c in categories)
                          _CategoryRow(
                            category: c,
                            count: ref.watch(
                              categoryTransactionCountProvider(c.id),
                            ),
                            onTap: () => _openForm(context, existing: c),
                            onDelete: () => _confirmDelete(context, ref, c),
                          ),
                      const SizedBox(height: Insets.sm),
                      _CreateCustomCategoryTile(
                        onTap: () => _openForm(context),
                      ),
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

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.customOnly, required this.onChanged});

  final bool customOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(bool value, String label) {
      final selected = customOnly == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
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
          segment(false, 'All Categories'),
          segment(true, 'Custom Categories'),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.count,
    required this.onTap,
    required this.onDelete,
  });

  final Category category;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            leading: CategoryAvatar(category: category),
            title: Text(
              category.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              <String>[
                if (category.isDefault) 'Default',
                '$count transaction${count == 1 ? '' : 's'}',
              ].join(' · '),
            ),
            trailing: category.isDefault
                ? const IconButton(
                    tooltip: 'Default categories cannot be deleted',
                    icon: Icon(Icons.lock_outline),
                    onPressed: null,
                  )
                : IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CreateCustomCategoryTile extends StatelessWidget {
  const _CreateCustomCategoryTile({required this.onTap});

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
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(width: Insets.sm + Insets.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Create Custom Category',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Add a category that fits your needs',
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

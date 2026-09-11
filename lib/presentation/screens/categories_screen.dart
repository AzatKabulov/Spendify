import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_avatar.dart';
import '../widgets/error_view.dart';
import 'category_form_screen.dart';

/// List / create / edit / delete categories.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: categoriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorView(
          message: "Couldn't load your categories.",
          detail: e,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (categories) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final c = categories[index];
            final count = ref.watch(categoryTransactionCountProvider(c.id));
            return ListTile(
              leading: CategoryAvatar(category: c),
              title: Text(c.name),
              subtitle: Text(
                <String>[
                  if (c.isDefault) 'Default',
                  '$count transaction${count == 1 ? '' : 's'}',
                ].join(' · '),
              ),
              trailing: c.isDefault
                  ? const IconButton(
                      tooltip: 'Default categories cannot be deleted',
                      icon: Icon(Icons.lock_outline),
                      onPressed: null,
                    )
                  : IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, c),
                    ),
              onTap: () => _openForm(context, existing: c),
            );
          },
        ),
      ),
    );
  }
}

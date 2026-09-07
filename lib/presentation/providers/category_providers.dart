import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category.dart';
import 'repository_providers.dart';

/// Live list of the user's categories, sorted by name (case-insensitive).
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAll().map((list) {
    final sorted = [...list]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  });
});

/// The categories as an id -> Category map, for O(1) lookups from list rows.
final categoriesByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c};
});

/// A single category by id (may be `null` if it was deleted).
final categoryByIdProvider = Provider.family<Category?, String>((ref, id) {
  return ref.watch(categoriesByIdProvider)[id];
});

/// Category to pre-select on the *add* form: the last-used one if it still
/// exists, otherwise the first category. `null` only if there are no
/// categories at all. Supports the 60-second target (CLAUDE.md §6).
final defaultNewTransactionCategoryProvider = Provider<Category?>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  if (categories.isEmpty) return null;
  final lastUsedId = ref.watch(appPreferencesProvider).lastUsedCategoryId;
  if (lastUsedId != null) {
    for (final c in categories) {
      if (c.id == lastUsedId) return c;
    }
  }
  return categories.first;
});

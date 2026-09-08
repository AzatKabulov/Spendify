import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import 'repository_providers.dart';
import 'transaction_providers.dart';

int _byNameCi(Category a, Category b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// Live **non-deleted** categories, sorted by name. This is the list for
/// pickers (transaction form, budget scope).
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAll().map((list) => [...list]..sort(_byNameCi));
});

/// Live categories **including soft-deleted ones**. Only for resolving the
/// name/icon of a deleted category on an existing transaction row — never for
/// pickers.
final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAllIncludingDeleted().map(
    (list) => [...list]..sort(_byNameCi),
  );
});

/// Non-deleted categories as an id -> Category map (picker lookups).
final categoriesByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c};
});

/// Every category (incl. deleted) as an id -> Category map, for **display**
/// resolution of transaction rows and historical aggregates.
final allCategoriesByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(allCategoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c};
});

/// A category by id for display — resolves deleted categories too.
final categoryDisplayProvider = Provider.family<Category?, String>((ref, id) {
  return ref.watch(allCategoriesByIdProvider)[id];
});

/// Category to pre-select on the *add* transaction form: last-used if it still
/// exists, otherwise the first category. `null` only if there are none.
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

/// How many non-deleted transactions reference a category — for the
/// "this category has N transactions" delete warning.
final categoryTransactionCountProvider = Provider.family<int, String>((
  ref,
  id,
) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  return transactions.where((t) => t.categoryId == id).length;
});

/// Write actions for categories. All category business logic lives here.
final categoryActionsProvider = Provider<CategoryActions>((ref) {
  return CategoryActions(
    repository: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

class CategoryActions {
  CategoryActions({
    required CategoryRepository repository,
    required this.clock,
    required this.newId,
  }) : _repo = repository;

  final CategoryRepository _repo;
  final Clock clock;
  final IdGenerator newId;

  Future<Category> create({
    required String name,
    required int iconCode,
    required int colorValue,
  }) {
    final category = Category.create(
      id: newId(),
      userId: kLocalUserId,
      name: name.trim(),
      iconCode: iconCode,
      colorValue: colorValue,
      now: clock(),
    );
    return _repo.add(category);
  }

  Future<Category> edit(
    Category original, {
    required String name,
    required int iconCode,
    required int colorValue,
  }) {
    return _repo.update(
      original.copyWith(
        name: name.trim(),
        iconCode: iconCode,
        colorValue: colorValue,
      ),
    );
  }

  /// Soft-delete. Transactions in this category are untouched (CLAUDE.md §8).
  /// Default categories cannot be deleted — the caller must gate this.
  Future<void> delete(String id) => _repo.delete(id);
}

/// Case-insensitive uniqueness check against the current non-deleted set.
/// Used inline by the category form.
bool isCategoryNameTaken(
  Iterable<Category> existing,
  String name, {
  String? excludingId,
}) {
  final needle = name.trim().toLowerCase();
  return existing.any(
    (c) => c.id != excludingId && c.name.toLowerCase() == needle,
  );
}

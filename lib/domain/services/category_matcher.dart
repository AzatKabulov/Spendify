/// Maps Gemini's free-text category ("Groceries", "food", "Restaurant") onto
/// one of the user's existing categories. Pure — takes the category list in.
///
/// **No confident match -> return null and leave the picker empty.** Never
/// invent a category, never silently fall back to "Other": a wrong pre-filled
/// category is worse than an empty one, because people accept defaults without
/// reading (CLAUDE.md §7 / Phase 7 Part C).
library;

import '../entities/category.dart';

/// The id of the best-matching non-deleted category, or `null`.
///
/// Order: (1) exact, case-insensitive name match; (2) one contains the other
/// (case-insensitive), preferring the shortest such candidate; otherwise null.
String? matchCategoryId(String? aiLabel, Iterable<Category> categories) {
  final needle = aiLabel?.trim().toLowerCase();
  if (needle == null || needle.isEmpty) return null;

  final live = categories.where((c) => !c.isDeleted).toList(growable: false);

  for (final c in live) {
    if (c.name.trim().toLowerCase() == needle) return c.id;
  }

  Category? best;
  for (final c in live) {
    final name = c.name.trim().toLowerCase();
    if (name.isEmpty) continue;
    if (name.contains(needle) || needle.contains(name)) {
      if (best == null || c.name.length < best.name.length) best = c;
    }
  }
  return best?.id;
}

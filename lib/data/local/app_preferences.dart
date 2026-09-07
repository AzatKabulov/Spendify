import 'package:hive/hive.dart';

import '../../core/constants.dart';

/// Small local UI preferences — not domain state, not synced. Phase 2 only
/// stores the last-used category id (drives the add-form default; CLAUDE.md §6).
abstract interface class AppPreferences {
  String? get lastUsedCategoryId;
  Future<void> setLastUsedCategoryId(String categoryId);
}

/// Backed by the encrypted `spendly_meta` box.
class HiveAppPreferences implements AppPreferences {
  HiveAppPreferences(this._meta);

  final Box<dynamic> _meta;

  @override
  String? get lastUsedCategoryId =>
      _meta.get(MetaKeys.lastUsedCategoryId) as String?;

  @override
  Future<void> setLastUsedCategoryId(String categoryId) =>
      _meta.put(MetaKeys.lastUsedCategoryId, categoryId);
}

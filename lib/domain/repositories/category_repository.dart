import '../entities/category.dart';
import 'syncable_repository.dart';

/// Storage contract for [Category].
abstract interface class CategoryRepository
    implements SyncableRepository<Category> {
  /// Ensure the default category set exists. Runs its seed exactly once over
  /// the lifetime of the install (guarded by a flag in the meta box), so a
  /// user who deletes a default category does not get it back on next launch.
  Future<void> ensureDefaultsSeeded();
}

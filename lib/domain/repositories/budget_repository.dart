import '../entities/budget.dart';
import 'syncable_repository.dart';

/// Storage contract for [Budget].
abstract interface class BudgetRepository
    implements SyncableRepository<Budget> {
  /// The live overall budget (`categoryId == null`), or `null` if none set.
  Future<Budget?> getOverall();

  /// The live budget for a specific category, or `null` if none set.
  Future<Budget?> getForCategory(String categoryId);
}

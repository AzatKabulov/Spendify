import '../entities/transaction.dart';
import 'syncable_repository.dart';

/// Storage contract for [Transaction]. Query helpers here stay simple in
/// Phase 1; date-range and category filters land with the reports work
/// (Phase 4), backed by `PeriodAggregate` rather than full scans.
abstract interface class TransactionRepository
    implements SyncableRepository<Transaction> {
  /// Live transactions whose [Transaction.date] falls in `[from, to)`,
  /// newest first.
  Future<List<Transaction>> getInDateRange({
    required DateTime from,
    required DateTime to,
  });

  /// Live transactions for one category, newest first.
  Future<List<Transaction>> getByCategory(String categoryId);
}

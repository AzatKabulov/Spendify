import '../entities/enums.dart';
import '../entities/period_aggregate.dart';

/// Storage contract for the [PeriodAggregate] report cache. Local-only: these
/// rows are derived from transactions and rebuilt, never synced.
abstract interface class PeriodAggregateRepository {
  /// One aggregate by its composite id, or `null`.
  Future<PeriodAggregate?> getById(String id);

  /// All cached aggregates of a given granularity for the current user.
  Future<List<PeriodAggregate>> getByPeriodType(PeriodType periodType);

  /// Every aggregate whose [PeriodAggregate.periodKey] matches, across
  /// categories (Phase 4 report screen reads this).
  Future<List<PeriodAggregate>> getForPeriodKey({
    required PeriodType periodType,
    required String periodKey,
  });

  /// Insert or replace an aggregate.
  Future<void> put(PeriodAggregate aggregate);

  /// Insert or replace many aggregates in one pass (recompute after a batch
  /// transaction change).
  Future<void> putAll(List<PeriodAggregate> aggregates);

  /// Wipe the whole cache (e.g. after a large sync pull).
  Future<void> clear();
}

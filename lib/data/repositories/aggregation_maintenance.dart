import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/period_aggregate_repository.dart';
import '../../domain/services/aggregation_service.dart';

/// Keeps the `PeriodAggregate` cache in step with transaction changes,
/// **incrementally** — every write touches only the eight aggregates that
/// transaction contributes to (daily/weekly/monthly/yearly × its category + the
/// period total), never the whole table.
///
/// Consistency guarantee: after any sequence of [applyCreate] / [applyDelete] /
/// [applyEdit], the cache must equal [rebuildAll] over the same transactions.
/// The "50 random operations" test enforces this — and it exercises the daily
/// buckets too now that `PeriodType.daily` is in `PeriodType.values`, which is
/// what drives every loop below.
class AggregationMaintenance {
  AggregationMaintenance(
    this._aggregates, {
    required this.userId,
    this.clock = systemClock,
  });

  final PeriodAggregateRepository _aggregates;
  final Clock clock;
  final String userId;

  /// A new (or undo-restored) transaction: add its amounts.
  Future<void> applyCreate(Transaction t) => _apply(t, sign: 1);

  /// A soft-deleted transaction: subtract its amounts.
  Future<void> applyDelete(Transaction t) => _apply(t, sign: -1);

  /// An edited transaction. An edit can change amount, type, category **and**
  /// date (which moves it to different period buckets), so this reverses the
  /// old values from the old buckets and applies the new values to the new
  /// buckets — never an in-place diff.
  Future<void> applyEdit({
    required Transaction before,
    required Transaction after,
  }) async {
    await _apply(before, sign: -1);
    await _apply(after, sign: 1);
  }

  /// Wipe and recompute every aggregate from [allTransactions]. The drift
  /// backstop — incremental counters can go wrong (bugs, interrupted writes,
  /// and from Phase 6, sync). Exposed via a settings action and run once
  /// automatically on first launch after Phase 4 ships.
  Future<void> rebuildAll(Iterable<Transaction> allTransactions) async {
    final computed = computeAggregates(
      transactions: allTransactions,
      userId: userId,
      now: clock(),
    );
    await _aggregates.clear();
    if (computed.isNotEmpty) await _aggregates.putAll(computed);
  }

  Future<void> _apply(Transaction t, {required int sign}) async {
    final now = clock();
    final incomeDelta = t.type == TransactionType.income
        ? sign * t.amountMinor
        : 0;
    final expenseDelta = t.type == TransactionType.expense
        ? sign * t.amountMinor
        : 0;

    final bumped = <PeriodAggregate>[];
    for (final type in PeriodType.values) {
      final periodKey = periodKeyFor(t.date, type);
      bumped.add(
        await _bumped(
          type,
          periodKey,
          t.categoryId,
          incomeDelta,
          expenseDelta,
          sign,
          now,
        ),
      );
      bumped.add(
        await _bumped(
          type,
          periodKey,
          null,
          incomeDelta,
          expenseDelta,
          sign,
          now,
        ),
      );
    }

    // A bucket emptied by a subtraction is removed, so the incremental cache
    // stays byte-for-byte identical to a full rebuild (which never emits an
    // all-zero row).
    final toPut = <PeriodAggregate>[];
    final toRemove = <String>[];
    for (final agg in bumped) {
      if (agg.totalIncomeMinor == 0 &&
          agg.totalExpenseMinor == 0 &&
          agg.transactionCount == 0) {
        toRemove.add(agg.id);
      } else {
        toPut.add(agg);
      }
    }

    try {
      if (toPut.isNotEmpty) await _aggregates.putAll(toPut);
      if (toRemove.isNotEmpty) await _aggregates.removeAll(toRemove);
    } catch (error, stack) {
      // The eight aggregates are now inconsistent — surface it loudly rather
      // than silently. rebuildAll() is the recovery path. Debug-only so no
      // record ids reach a production log (Phase 10 audit).
      if (!kReleaseMode) {
        debugPrint(
          'AGGREGATE MAINTENANCE FAILED for transaction ${t.id} (sign $sign): '
          '$error\n$stack',
        );
      }
      rethrow;
    }
  }

  Future<PeriodAggregate> _bumped(
    PeriodType type,
    String periodKey,
    String? categoryId,
    int incomeDelta,
    int expenseDelta,
    int countDelta,
    DateTime now,
  ) async {
    final id = PeriodAggregate.buildId(
      userId: userId,
      periodType: type,
      periodKey: periodKey,
      categoryId: categoryId,
    );
    final current = await _aggregates.getById(id);
    final base =
        current ??
        PeriodAggregate(
          id: id,
          userId: userId,
          periodType: type,
          periodKey: periodKey,
          categoryId: categoryId,
          totalIncomeMinor: 0,
          totalExpenseMinor: 0,
          transactionCount: 0,
          updatedAt: now,
        );
    return base.copyWith(
      totalIncomeMinor: base.totalIncomeMinor + incomeDelta,
      totalExpenseMinor: base.totalExpenseMinor + expenseDelta,
      transactionCount: base.transactionCount + countDelta,
      updatedAt: now,
    );
  }
}

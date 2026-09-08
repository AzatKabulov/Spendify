import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/id_generator.dart';
import '../../data/local/app_preferences.dart';
import '../../data/local/hive_initializer.dart';
import '../../data/repositories/aggregation_maintenance.dart';
import '../../data/repositories/hive_advice_record_repository.dart';
import '../../data/repositories/hive_budget_repository.dart';
import '../../data/repositories/hive_category_repository.dart';
import '../../data/repositories/hive_gamification_state_repository.dart';
import '../../data/repositories/hive_period_aggregate_repository.dart';
import '../../data/repositories/hive_transaction_repository.dart';
import '../../domain/repositories/advice_record_repository.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/gamification_state_repository.dart';
import '../../domain/repositories/period_aggregate_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

/// The opened, encrypted Hive boxes. **Must be overridden in `main()`** with the
/// value from `bootstrapHive()` — the app cannot run without real storage, so
/// the fallback throws rather than silently using an empty in-memory store.
final hiveStoreProvider = Provider<HiveStore>(
  (ref) => throw StateError(
    'hiveStoreProvider was not overridden — call bootstrapHive() in main() '
    'and pass the result via ProviderScope(overrides: ...).',
  ),
);

/// Wall clock used by repositories for `updatedAt` stamping (UTC). Override in
/// tests.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// **Local** wall-clock "now", for calendar/period logic — budget periods
/// (Phase 3), report periods (Phase 4). Distinct from [clockProvider], which is
/// UTC for storage timestamps. Override in tests to pin the current period.
final localTimeProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Id factory for new records. Override in tests for deterministic ids.
final idGeneratorProvider = Provider<IdGenerator>((ref) => generateUuidV4);

/// Small local UI preferences (last-used category, …), backed by the meta box.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return HiveAppPreferences(ref.watch(hiveStoreProvider).meta);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return HiveTransactionRepository(
    ref.watch(hiveStoreProvider).transactions,
    clock: ref.watch(clockProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final store = ref.watch(hiveStoreProvider);
  return HiveCategoryRepository(
    store.categories,
    metaBox: store.meta,
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return HiveBudgetRepository(
    ref.watch(hiveStoreProvider).budgets,
    clock: ref.watch(clockProvider),
  );
});

final gamificationStateRepositoryProvider =
    Provider<GamificationStateRepository>((ref) {
      return HiveGamificationStateRepository(
        ref.watch(hiveStoreProvider).gamificationState,
        clock: ref.watch(clockProvider),
      );
    });

final adviceRecordRepositoryProvider = Provider<AdviceRecordRepository>((ref) {
  return HiveAdviceRecordRepository(ref.watch(hiveStoreProvider).adviceRecords);
});

final periodAggregateRepositoryProvider = Provider<PeriodAggregateRepository>((
  ref,
) {
  return HivePeriodAggregateRepository(
    ref.watch(hiveStoreProvider).periodAggregates,
  );
});

/// Keeps the PeriodAggregate cache in step with transaction writes (Phase 4).
final aggregationMaintenanceProvider = Provider<AggregationMaintenance>((ref) {
  return AggregationMaintenance(
    ref.watch(periodAggregateRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

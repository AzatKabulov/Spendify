import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../data/local/hive_initializer.dart';
import '../../data/local/user_id_migration.dart';
import '../../data/repositories/aggregation_maintenance.dart';
import '../../data/repositories/hive_category_repository.dart';
import '../../data/repositories/hive_period_aggregate_repository.dart';
import '../../data/repositories/hive_transaction_repository.dart';

/// Everything that must happen for a user's local data to be ready to show,
/// once their real Firebase UID is known (first sign-in, or a resumed migration
/// on a later launch):
///
///  1. migrate any Phase 1 placeholder-owned records to this UID (CLAUDE.md
///     §4.1) — idempotent + resumable;
///  2. seed the default category set if this device has none yet;
///  3. (re)build the `PeriodAggregate` cache if it is missing — the migration
///     drops it because aggregate ids embed the UID.
///
/// All uid-scoped; nothing here touches the network.
class UserDataPreparer {
  UserDataPreparer(this._store, {this.clock = systemClock});

  final HiveStore _store;
  final Clock clock;

  Future<void> prepareFor(String uid) async {
    final migration = UserIdMigration(_store, clock: clock);
    final result = await migration.run(realUid: uid);

    final categories = HiveCategoryRepository(
      _store.categories,
      metaBox: _store.meta,
      userId: uid,
      clock: clock,
    );
    await categories.ensureDefaultsSeeded();

    final aggregatesBuilt =
        _store.meta.get(MetaKeys.aggregatesBuilt, defaultValue: false) as bool;
    if (!aggregatesBuilt) {
      final transactions = HiveTransactionRepository(
        _store.transactions,
        userId: uid,
        clock: clock,
      );
      final maintenance = AggregationMaintenance(
        HivePeriodAggregateRepository(_store.periodAggregates),
        userId: uid,
        clock: clock,
      );
      await maintenance.rebuildAll(await transactions.getAll());
      await _store.meta.put(MetaKeys.aggregatesBuilt, true);
    }

    if (!kReleaseMode) {
      debugPrint(
        'PREPARE: uid=$uid migration=$result '
        'aggregatesBuilt=${_store.meta.get(MetaKeys.aggregatesBuilt)}',
      );
    }
  }
}

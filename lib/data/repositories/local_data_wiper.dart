import '../local/auth_session_store.dart';
import '../local/hive_initializer.dart';

/// Erases everything Spendly keeps on this device (Phase 10 "Delete all local
/// data").
///
/// **Decision (stated to the user in the confirmation dialog):** this clears
/// every local Hive box and the signed-in session. It does **NOT** delete the
/// Firestore backup — signing in again restores it. The device encryption key
/// is left in place; with every box empty there is nothing for it to protect,
/// and regenerating it risks a messy first launch.
abstract interface class LocalDataWiper {
  Future<void> wipe();
}

class HiveLocalDataWiper implements LocalDataWiper {
  HiveLocalDataWiper(this._store, this._sessions);

  final HiveStore _store;
  final AuthSessionStore _sessions;

  @override
  Future<void> wipe() async {
    await _store.transactions.clear();
    await _store.categories.clear();
    await _store.budgets.clear();
    await _store.gamificationState.clear();
    await _store.adviceRecords.clear();
    await _store.periodAggregates.clear();
    await _store.meta.clear();
    await _sessions.clear();
  }
}

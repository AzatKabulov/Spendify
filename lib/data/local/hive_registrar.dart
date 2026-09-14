import 'package:hive/hive.dart';

import 'models/advice_record_model.dart';
import 'models/budget_model.dart';
import 'models/category_model.dart';
import 'models/enum_adapters.dart';
import 'models/gamification_state_model.dart';
import 'models/period_aggregate_model.dart';
import 'models/transaction_model.dart';

/// Registers every Hive adapter exactly once. Safe to call repeatedly (each
/// test file calls it), because Hive throws on a duplicate typeId and we guard
/// with [Hive.isAdapterRegistered].
///
/// Enum adapters are registered before the model adapters that depend on them.
void registerSpendifyHiveAdapters() {
  _register(TransactionTypeAdapter());
  _register(TransactionSourceAdapter());
  _register(BudgetPeriodAdapter());
  _register(PeriodTypeAdapter());
  _register(SyncStatusAdapter());

  _register(TransactionModelAdapter());
  _register(CategoryModelAdapter());
  _register(BudgetModelAdapter());
  _register(GamificationStateModelAdapter());
  _register(AdviceRecordModelAdapter());
  _register(PeriodAggregateModelAdapter());
}

void _register<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_exporter.dart';
import '../../data/repositories/local_data_wiper.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Builds the JSON data export (Phase 10). Only valid behind `AuthGate` — it
/// reads uid-scoped repositories.
final dataExporterProvider = Provider<DataExporter>((ref) {
  return DataExporter(
    transactions: ref.watch(transactionRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    gamification: ref.watch(gamificationStateRepositoryProvider),
  );
});

/// "Delete all local data" (Phase 10). Overridable in tests.
final localDataWiperProvider = Provider<LocalDataWiper>((ref) {
  return HiveLocalDataWiper(
    ref.watch(hiveStoreProvider),
    ref.watch(authSessionStoreProvider),
  );
});

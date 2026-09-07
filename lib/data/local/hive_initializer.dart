import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import 'encryption_key_store.dart';
import 'hive_registrar.dart';
import 'models/advice_record_model.dart';
import 'models/budget_model.dart';
import 'models/category_model.dart';
import 'models/gamification_state_model.dart';
import 'models/period_aggregate_model.dart';
import 'models/transaction_model.dart';

/// Handle to the opened, encrypted Hive boxes. Held for the app's lifetime and
/// handed to the repositories.
class HiveStore {
  const HiveStore({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.gamificationState,
    required this.adviceRecords,
    required this.periodAggregates,
    required this.meta,
  });

  final Box<TransactionModel> transactions;
  final Box<CategoryModel> categories;
  final Box<BudgetModel> budgets;
  final Box<GamificationStateModel> gamificationState;
  final Box<AdviceRecordModel> adviceRecords;
  final Box<PeriodAggregateModel> periodAggregates;
  final Box<dynamic> meta;

  Future<void> close() => Hive.close();
}

/// Full app bootstrap: init Hive for Flutter, register adapters, fetch the
/// AES key from the Keystore, and open every box encrypted.
///
/// Call once from `main()` before `runApp`.
Future<HiveStore> bootstrapHive({EncryptionKeyStore? keyStore}) async {
  await Hive.initFlutter();
  registerSpendlyHiveAdapters();

  final store = keyStore ?? SecureStorageEncryptionKeyStore();
  final Uint8List key = await store.getOrCreateKey();
  final cipher = HiveAesCipher(key);

  return openEncryptedBoxes(cipher);
}

/// Opens all boxes with [cipher]. Extracted from [bootstrapHive] so tests can
/// exercise it against a temp dir + fixed key without Flutter plugins.
///
/// If a box fails to open (corruption, an interrupted write, a key mismatch),
/// it is deleted from disk and reopened empty. Firestore is the backstop from
/// Phase 6; before that, a corrupt local box is unrecoverable anyway, and a
/// working empty box beats a crash loop. A second failure is fatal
/// ([BoxUnavailableException]).
Future<HiveStore> openEncryptedBoxes(HiveAesCipher cipher) async {
  return HiveStore(
    transactions: await _openBox<TransactionModel>(
      HiveBoxes.transactions,
      cipher,
    ),
    categories: await _openBox<CategoryModel>(HiveBoxes.categories, cipher),
    budgets: await _openBox<BudgetModel>(HiveBoxes.budgets, cipher),
    gamificationState: await _openBox<GamificationStateModel>(
      HiveBoxes.gamificationState,
      cipher,
    ),
    adviceRecords: await _openBox<AdviceRecordModel>(
      HiveBoxes.adviceRecords,
      cipher,
    ),
    periodAggregates: await _openBox<PeriodAggregateModel>(
      HiveBoxes.periodAggregates,
      cipher,
    ),
    meta: await _openDynamicBox(HiveBoxes.meta, cipher),
  );
}

Future<Box<T>> _openBox<T>(String name, HiveAesCipher cipher) async {
  try {
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  } catch (first) {
    try {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (second) {
      throw BoxUnavailableException(name, cause: second);
    }
  }
}

Future<Box<dynamic>> _openDynamicBox(String name, HiveAesCipher cipher) async {
  try {
    return await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
  } catch (first) {
    try {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
    } catch (second) {
      throw BoxUnavailableException(name, cause: second);
    }
  }
}

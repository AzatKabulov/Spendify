import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/local/auth_session_store.dart';
import 'package:spendly/data/repositories/hive_budget_repository.dart';
import 'package:spendly/data/repositories/hive_category_repository.dart';
import 'package:spendly/data/repositories/hive_transaction_repository.dart';
import 'package:spendly/data/repositories/local_data_wiper.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/transaction.dart';

import '../../support/hive_test_harness.dart';

/// Minimal in-memory [AuthSessionStore].
class _MemSession implements AuthSessionStore {
  AuthSession? _s = const AuthSession(uid: 'u1', email: 'x@y.z');
  bool cleared = false;

  @override
  Future<AuthSession?> read() async => _s;
  @override
  Future<void> write(AuthSession session) async => _s = session;
  @override
  Future<void> clear() async {
    _s = null;
    cleared = true;
  }
}

void main() {
  late HiveTestHarness harness;
  late _MemSession sessions;

  setUp(() async {
    harness = await HiveTestHarness.start();
    sessions = _MemSession();
  });
  tearDown(() => harness.dispose());

  test(
    'wipe clears every box + the session; app re-reads a clean state',
    () async {
      final txns = HiveTransactionRepository(
        harness.store.transactions,
        userId: kLocalUserId,
        clock: () => DateTime.utc(2026, 9, 6),
      );
      final cats = HiveCategoryRepository(
        harness.store.categories,
        metaBox: harness.store.meta,
        userId: kLocalUserId,
        clock: () => DateTime.utc(2026, 9, 6),
        idGenerator: () => 'id',
      );
      final budgets = HiveBudgetRepository(
        harness.store.budgets,
        userId: kLocalUserId,
        clock: () => DateTime.utc(2026, 9, 6),
      );

      await cats.ensureDefaultsSeeded();
      await txns.add(
        Transaction.create(
          id: 't1',
          userId: kLocalUserId,
          amountMinor: 1000,
          type: TransactionType.expense,
          categoryId: 'c',
          date: DateTime(2026, 9, 6),
          now: DateTime.utc(2026, 9, 6),
        ),
      );
      await budgets.add(
        Budget.create(
          id: 'b1',
          userId: kLocalUserId,
          limitAmountMinor: 5000,
          period: BudgetPeriod.monthly,
          startDate: DateTime(2026, 9, 1),
          now: DateTime.utc(2026, 9, 1),
        ),
      );
      await harness.store.meta.put(MetaKeys.aiConsent, 'granted');

      expect(harness.store.transactions.isEmpty, isFalse);
      expect(harness.store.categories.isEmpty, isFalse);

      await HiveLocalDataWiper(harness.store, sessions).wipe();

      // every box empty
      expect(harness.store.transactions.length, 0);
      expect(harness.store.categories.length, 0);
      expect(harness.store.budgets.length, 0);
      expect(harness.store.gamificationState.length, 0);
      expect(harness.store.adviceRecords.length, 0);
      expect(harness.store.periodAggregates.length, 0);
      expect(harness.store.meta.length, 0);
      expect(sessions.cleared, isTrue);

      // fresh repositories over the same (now-empty) boxes read a clean state
      // without crashing on missing records
      final freshTxns = HiveTransactionRepository(
        harness.store.transactions,
        userId: kLocalUserId,
        clock: () => DateTime.utc(2026, 9, 6),
      );
      expect(await freshTxns.getAll(), isEmpty);
      expect(await freshTxns.getById('t1'), isNull);

      final freshCats = HiveCategoryRepository(
        harness.store.categories,
        metaBox: harness.store.meta,
        userId: kLocalUserId,
        clock: () => DateTime.utc(2026, 9, 6),
        idGenerator: () => 'id2',
      );
      expect(await freshCats.getAll(), isEmpty);
      // defaults can be re-seeded (the seeded flag was wiped from meta)
      await freshCats.ensureDefaultsSeeded();
      expect((await freshCats.getAll()).isNotEmpty, isTrue);
    },
  );
}

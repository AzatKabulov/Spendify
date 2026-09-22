import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/local/hive_initializer.dart';
import '../../data/local/models/budget_model.dart';
import '../../data/local/models/gamification_state_model.dart';
import '../../data/local/models/transaction_model.dart';
import '../../data/repositories/aggregation_maintenance.dart';
import '../../data/repositories/hive_category_repository.dart';
import '../../data/repositories/hive_period_aggregate_repository.dart';
import '../../data/repositories/hive_transaction_repository.dart';
import '../../domain/entities/enums.dart';
import '../constants.dart';

/// Debug-only demo dataset (Phase 12 Part E — demo prep).
///
/// Loads a believable ~4-month history spread across the default categories
/// (with income), three budgets — one **safe**, one **approaching**, one
/// **exceeded** for the current month — and a gamification state with a mid
/// level, several badges and a live 5-day streak.
///
/// Inert unless `--dart-define=DEMO_SEED=true`, and never in release. Idempotent:
/// does nothing if any transaction already exists, so it will not clobber real
/// data. To reload it, use Settings → "Delete all local data" first (or a fresh
/// install), then relaunch with the flag.
///
///     flutter run --dart-define=DEMO_SEED=true
///     flutter run --dart-define=DEMO_SEED=true --dart-define=GEMINI_API_KEY=…
Future<bool> maybeDemoSeed(HiveStore store) async {
  if (kReleaseMode) return false;
  if (!const bool.fromEnvironment('DEMO_SEED')) return false;
  if (store.transactions.isNotEmpty) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysBack(int d) => DateTime(today.year, today.month, today.day - d);

  // --- 1. categories ---------------------------------------------------
  final catRepo = HiveCategoryRepository(
    store.categories,
    metaBox: store.meta,
    userId: kLocalUserId,
  );
  await catRepo.ensureDefaultsSeeded();
  final categories = await catRepo.getAll();
  String cat(String name) => categories.firstWhere((c) => c.name == name).id;

  final food = cat('Food');
  final transport = cat('Transport');
  final groceries = cat('Groceries');
  final bills = cat('Bills');
  final entertainment = cat('Entertainment');
  final health = cat('Health');
  final education = cat('Education');
  final other = cat('Other');

  // --- 2. transactions ----------------------------------------------
  final rng = Random(7);
  final models = <String, TransactionModel>{};
  var seq = 0;

  void add({
    required int amountMinor,
    required String categoryId,
    required DateTime date,
    TransactionType type = TransactionType.expense,
    String? note,
    TransactionSource source = TransactionSource.manual,
  }) {
    final id = 'demo-${seq++}';
    models[id] = TransactionModel(
      id: id,
      userId: kLocalUserId,
      amountMinor: amountMinor,
      type: type,
      categoryId: categoryId,
      date: date,
      note: note,
      source: source,
      createdAt: date,
      updatedAt: date,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
  }

  int between(int lowSen, int highSen) =>
      lowSen + rng.nextInt(highSen - lowSen + 1);

  // ~120 days of history.
  for (var d = 120; d >= 0; d--) {
    final date = daysBack(d);

    // Food — most days, sometimes twice.
    if (rng.nextInt(10) != 0) {
      add(amountMinor: between(750, 2600), categoryId: food, date: date);
      if (rng.nextInt(3) == 0) {
        add(amountMinor: between(1200, 4800), categoryId: food, date: date);
      }
    }
    // Transport — school/work days.
    if (date.weekday <= 5 && rng.nextInt(3) != 0) {
      add(amountMinor: between(300, 1600), categoryId: transport, date: date);
    }
    // Groceries — a couple of times a week.
    if (rng.nextInt(4) == 0) {
      add(amountMinor: between(3500, 13000), categoryId: groceries, date: date);
    }
    // Entertainment — a few times a week.
    if (rng.nextInt(3) == 0) {
      add(
        amountMinor: between(1500, 6500),
        categoryId: entertainment,
        date: date,
      );
    }
    // Health — occasional.
    if (rng.nextInt(18) == 0) {
      add(amountMinor: between(2000, 16000), categoryId: health, date: date);
    }
    // Education — occasional, larger.
    if (rng.nextInt(20) == 0) {
      add(amountMinor: between(3000, 22000), categoryId: education, date: date);
    }
    // Other — rare.
    if (rng.nextInt(25) == 0) {
      add(amountMinor: between(1000, 9000), categoryId: other, date: date);
    }
  }

  // Monthly bills, on the 3rd of each of the last four months.
  for (var m = 0; m < 4; m++) {
    final billDate = DateTime(today.year, today.month - m, 3);
    if (!billDate.isAfter(today)) {
      add(
        amountMinor: between(8000, 21000),
        categoryId: bills,
        date: billDate,
        note: 'Phone + internet',
      );
    }
  }

  // Income — allowance / part-time, twice a month.
  for (var m = 0; m < 4; m++) {
    for (final day in <int>[1, 16]) {
      final payDate = DateTime(today.year, today.month - m, day);
      if (!payDate.isAfter(today)) {
        add(
          amountMinor: 150000 + rng.nextInt(60000),
          categoryId: other,
          date: payDate,
          type: TransactionType.income,
          note: day == 1 ? 'Allowance' : 'Part-time',
        );
      }
    }
  }

  // Guarantee a populated current week for the live demo + budget states.
  for (var d = 0; d < 6; d++) {
    final date = daysBack(d);
    add(amountMinor: between(900, 2400), categoryId: food, date: date);
    if (d.isEven) {
      add(amountMinor: between(400, 1500), categoryId: transport, date: date);
    }
  }
  add(amountMinor: 8900, categoryId: groceries, date: daysBack(1));
  add(amountMinor: 6200, categoryId: groceries, date: daysBack(4));
  add(amountMinor: 4500, categoryId: entertainment, date: daysBack(2));

  await store.transactions.putAll(models);

  // --- 3. rebuild the aggregate cache from the seeded data --------------
  final txnRepo = HiveTransactionRepository(
    store.transactions,
    userId: kLocalUserId,
  );
  final allTxns = await txnRepo.getAll();
  await AggregationMaintenance(
    HivePeriodAggregateRepository(store.periodAggregates),
    userId: kLocalUserId,
  ).rebuildAll(allTxns);
  await store.meta.put(MetaKeys.aggregatesBuilt, true);

  // --- 4. budgets — one in each warning state this month ---------------
  final monthStart = DateTime(today.year, today.month, 1);
  int monthSpend(String categoryId) => allTxns
      .where(
        (t) =>
            !t.isDeleted &&
            t.type == TransactionType.expense &&
            t.categoryId == categoryId &&
            !t.date.isBefore(monthStart),
      )
      .fold(0, (sum, t) => sum + t.amountMinor);

  /// A monthly category budget whose limit puts current spend at [fraction].
  BudgetModel budget(
    String id,
    String? categoryId,
    int spent,
    double fraction,
  ) {
    final limit = fraction <= 0
        ? 50000
        : ((spent / fraction) / 100).round() * 100; // round to the ringgit
    return BudgetModel(
      id: id,
      userId: kLocalUserId,
      categoryId: categoryId,
      limitAmountMinor: limit < 1000 ? 50000 : limit,
      period: BudgetPeriod.monthly,
      startDate: monthStart,
      createdAt: daysBack(40),
      updatedAt: daysBack(40),
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
  }

  await store.budgets.putAll(<String, BudgetModel>{
    // exceeded: spent = 130% of the limit
    'demo-b-food': budget('demo-b-food', food, monthSpend(food), 1.30),
    // approaching: spent = 90% of the limit
    'demo-b-groc': budget(
      'demo-b-groc',
      groceries,
      monthSpend(groceries),
      0.90,
    ),
    // safe: spent = 45% of the limit
    'demo-b-ent': budget(
      'demo-b-ent',
      entertainment,
      monthSpend(entertainment),
      0.45,
    ),
  });

  // --- 5. gamification state -----------------------------------------
  // XP 1500 == level 5 on the curve (50·L·(L+1) − 100): L5 = 1400, L6 = 2000.
  await store.gamificationState.put(
    kLocalUserId,
    GamificationStateModel(
      userId: kLocalUserId,
      xp: 1560,
      coins: 214,
      level: 5,
      currentStreak: 5,
      longestStreak: 14,
      lastActivityDate: DateTime.utc(today.year, today.month, today.day),
      unlockedBadgeIds: <String>[
        'first_transaction',
        'transactions_10',
        'transactions_50',
        'transactions_100',
        'first_budget',
        'budget_kept',
        'streak_3',
        'all_categories',
        'level_5',
      ],
      updatedAt: now.toUtc(),
      syncStatus: SyncStatus.pending,
      transactionsLogged: models.length,
      budgetsCreated: 3,
      budgetPeriodsWithinLimit: 2,
      scannedTransactionsLogged: 0,
      recentEventIds: const <String>[],
    ),
  );

  if (kDebugMode) {
    debugPrint(
      'DEMO SEED: ${models.length} transactions, 3 budgets, gamification L5 '
      'loaded.',
    );
  }
  return true;
}

import 'dart:math';

import '../../data/local/hive_initializer.dart';
import '../../data/local/models/transaction_model.dart';
import '../../domain/entities/enums.dart';

/// Debug-only helper: bulk-inserts synthetic transactions so the reports and
/// performance work (Phases 4, 11) have a realistic dataset. Inert unless
/// `--dart-define=DEV_SEED_TRANSACTIONS=<n>` is passed. Never runs in release.
///
///     flutter run --dart-define=DEV_SEED_TRANSACTIONS=1000
Future<void> maybeDevSeedTransactions(HiveStore store) async {
  const raw = String.fromEnvironment('DEV_SEED_TRANSACTIONS');
  final target = int.tryParse(raw) ?? 0;
  if (target <= 0) return;
  if (store.transactions.length >= target) return;

  final rng = Random(42);
  final categoryIds = store.categories.values
      .where((c) => !c.isDeleted)
      .map((c) => c.id)
      .toList();
  if (categoryIds.isEmpty) return;

  final now = DateTime.now().toUtc();
  // Income is rarer and always lands on the last category (typically "Other"),
  // so seeded data doesn't read as e.g. "Groceries +RM 1,800".
  final incomeCategoryId = categoryIds.last;
  final expenseCategoryIds = categoryIds.length > 1
      ? categoryIds.sublist(0, categoryIds.length - 1)
      : categoryIds;

  final batch = <String, TransactionModel>{};
  for (var i = store.transactions.length; i < target; i++) {
    final daysAgo = rng.nextInt(365 * 2);
    final date = DateTime(now.year, now.month, now.day - daysAgo);
    final isIncome = rng.nextInt(12) == 0;
    batch['dev-$i'] = TransactionModel(
      id: 'dev-$i',
      userId: 'local-user',
      amountMinor: isIncome
          ? 150000 + rng.nextInt(400000)
          : 200 + rng.nextInt(20000),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      categoryId: isIncome
          ? incomeCategoryId
          : expenseCategoryIds[rng.nextInt(expenseCategoryIds.length)],
      date: date,
      note: rng.nextInt(3) == 0 ? 'dev note $i' : null,
      source: TransactionSource.manual,
      createdAt: date,
      updatedAt: date,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
  }
  await store.transactions.putAll(batch);
}

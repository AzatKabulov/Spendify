import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../core/id_generator.dart';
import '../../data/local/app_preferences.dart';
import '../../data/repositories/aggregation_maintenance.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/patch.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_ordering.dart';
import 'repository_providers.dart';

/// Live, display-ordered transaction list (newest date first; newest created
/// first within a day). Backed by the encrypted Hive box — works fully offline.
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll().map(sortTransactionsForDisplay);
});

/// Live cached report aggregates. The Phase 2/3 seams below read from here now
/// instead of scanning transactions.
final periodAggregatesProvider = StreamProvider<List<PeriodAggregate>>((ref) {
  return ref.watch(periodAggregateRepositoryProvider).watchAll();
});

/// Sum of the yearly period-total aggregates: all-time income − expense.
int _allTimeIncome(List<PeriodAggregate> aggs) => aggs
    .where((a) => a.periodType == PeriodType.yearly && a.categoryId == null)
    .fold(0, (sum, a) => sum + a.totalIncomeMinor);

int _allTimeExpense(List<PeriodAggregate> aggs) => aggs
    .where((a) => a.periodType == PeriodType.yearly && a.categoryId == null)
    .fold(0, (sum, a) => sum + a.totalExpenseMinor);

/// Current balance in sen (income − expense).
///
/// Phase 4: now derived from the cached yearly `PeriodAggregate` totals — a
/// handful of rows instead of the full transaction list. The widget contract
/// is unchanged.
final currentBalanceMinorProvider = Provider<int>((ref) {
  final aggs = ref.watch(periodAggregatesProvider).value ?? const [];
  return _allTimeIncome(aggs) - _allTimeExpense(aggs);
});

/// Income / expense split — same aggregate-backed source as the balance.
final currentTotalsProvider = Provider<({int incomeMinor, int expenseMinor})>((
  ref,
) {
  final aggs = ref.watch(periodAggregatesProvider).value ?? const [];
  return (
    incomeMinor: _allTimeIncome(aggs),
    expenseMinor: _allTimeExpense(aggs),
  );
});

/// Write actions for transactions. All transaction business logic lives here,
/// never in a widget (CLAUDE.md §8). Each write also updates the aggregate
/// cache incrementally (Phase 4).
final transactionActionsProvider = Provider<TransactionActions>((ref) {
  return TransactionActions(
    repository: ref.watch(transactionRepositoryProvider),
    preferences: ref.watch(appPreferencesProvider),
    maintenance: ref.watch(aggregationMaintenanceProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

class TransactionActions {
  TransactionActions({
    required TransactionRepository repository,
    required AppPreferences preferences,
    required AggregationMaintenance maintenance,
    required this.clock,
    required this.newId,
  }) : _repo = repository,
       _prefs = preferences,
       _aggregates = maintenance;

  final TransactionRepository _repo;
  final AppPreferences _prefs;
  final AggregationMaintenance _aggregates;
  final Clock clock;
  final IdGenerator newId;

  /// Create a manual transaction and remember its category as last-used.
  Future<Transaction> create({
    required int amountMinor,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    String? note,
  }) async {
    final txn = Transaction.create(
      id: newId(),
      userId: kLocalUserId,
      amountMinor: amountMinor,
      type: type,
      categoryId: categoryId,
      date: _dateOnly(date),
      now: clock(),
      note: _trimToNull(note),
    );
    final saved = await _repo.add(txn);
    await _aggregates.applyCreate(saved);
    await _prefs.setLastUsedCategoryId(categoryId);
    return saved;
  }

  /// Apply an edit to an existing transaction.
  Future<Transaction> edit(
    Transaction original, {
    required int amountMinor,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    String? note,
  }) async {
    final updated = original.copyWith(
      amountMinor: amountMinor,
      type: type,
      categoryId: categoryId,
      date: _dateOnly(date),
      note: patch(_trimToNull(note)),
    );
    final saved = await _repo.update(updated);
    await _aggregates.applyEdit(before: original, after: saved);
    await _prefs.setLastUsedCategoryId(categoryId);
    return saved;
  }

  /// Soft-delete (the row becomes a tombstone; [restore] undoes it).
  Future<void> delete(String id) async {
    final txn = await _repo.getByIdIncludingDeleted(id);
    await _repo.delete(id);
    if (txn != null && !txn.isDeleted) {
      await _aggregates.applyDelete(txn);
    }
  }

  /// Undo a [delete] — the row is live again, so it re-adds to the aggregates.
  Future<void> restore(String id) async {
    await _repo.restore(id);
    final txn = await _repo.getById(id);
    if (txn != null) await _aggregates.applyCreate(txn);
  }

  static String? _trimToNull(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// Strip the time component so "transaction date" is a calendar day.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

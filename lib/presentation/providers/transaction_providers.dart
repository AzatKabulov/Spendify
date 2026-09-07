import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/patch.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/balance_calculator.dart';
import '../../domain/services/transaction_ordering.dart';
import '../../data/local/app_preferences.dart';
import 'repository_providers.dart';

/// Live, display-ordered transaction list (newest date first; newest created
/// first within a day). Backed by the encrypted Hive box — works fully offline.
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll().map(sortTransactionsForDisplay);
});

/// Current balance in sen (income − expense).
///
/// **Phase 4 seam:** this provider is the *only* place the balance is derived.
/// It computes over the live list today; Phase 4 re-points it at cached
/// `PeriodAggregate` totals with no change to any widget.
final currentBalanceMinorProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  return calculateBalanceMinor(transactions);
});

/// Income / expense split, same seam as [currentBalanceMinorProvider].
final currentTotalsProvider = Provider<({int incomeMinor, int expenseMinor})>((
  ref,
) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  return calculateTotals(transactions);
});

/// Write actions for transactions. All transaction business logic lives here,
/// never in a widget (CLAUDE.md §8). UI calls these; it never touches a repo.
final transactionActionsProvider = Provider<TransactionActions>((ref) {
  return TransactionActions(
    repository: ref.watch(transactionRepositoryProvider),
    preferences: ref.watch(appPreferencesProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

class TransactionActions {
  TransactionActions({
    required TransactionRepository repository,
    required AppPreferences preferences,
    required this.clock,
    required this.newId,
  }) : _repo = repository,
       _prefs = preferences;

  final TransactionRepository _repo;
  final AppPreferences _prefs;
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
    await _prefs.setLastUsedCategoryId(categoryId);
    return saved;
  }

  /// Soft-delete (the row becomes a tombstone; [restore] undoes it).
  Future<void> delete(String id) => _repo.delete(id);

  /// Undo a [delete].
  Future<void> restore(String id) => _repo.restore(id);

  static String? _trimToNull(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// Strip the time component so "transaction date" is a calendar day.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

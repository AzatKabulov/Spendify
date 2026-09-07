import '../entities/enums.dart';
import '../entities/transaction.dart';

/// Pure balance logic. Data in, number out — no storage, no UI (CLAUDE.md §5).
///
/// **Seam for Phase 4:** the home screen reads the balance through a single
/// provider that calls this over the live transaction list. In Phase 4 that
/// provider is re-pointed at cached `PeriodAggregate` totals instead, with no
/// change to the widget or to this function's signature.
int calculateBalanceMinor(Iterable<Transaction> transactions) {
  var balance = 0;
  for (final t in transactions) {
    if (t.isDeleted) continue;
    balance += switch (t.type) {
      TransactionType.income => t.amountMinor,
      TransactionType.expense => -t.amountMinor,
    };
  }
  return balance;
}

/// Split totals, if a screen needs income and expense separately.
({int incomeMinor, int expenseMinor}) calculateTotals(
  Iterable<Transaction> transactions,
) {
  var income = 0;
  var expense = 0;
  for (final t in transactions) {
    if (t.isDeleted) continue;
    switch (t.type) {
      case TransactionType.income:
        income += t.amountMinor;
      case TransactionType.expense:
        expense += t.amountMinor;
    }
  }
  return (incomeMinor: income, expenseMinor: expense);
}

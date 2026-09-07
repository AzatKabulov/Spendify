/// Single source of truth for Hive `typeId` allocation.
///
/// A `typeId` is permanent: once data is written with it, reusing or changing
/// it corrupts reads. **Never** renumber. New types take the next free id.
///
/// ┌────┬──────────────────────────┬──────────────────────────────────────────┐
/// │ id │ type                     │ notes                                    │
/// ├────┼──────────────────────────┼──────────────────────────────────────────┤
/// │  0 │ TransactionModel         │ data/local/models/transaction_model.dart  │
/// │  1 │ CategoryModel            │ data/local/models/category_model.dart     │
/// │  2 │ BudgetModel              │ data/local/models/budget_model.dart       │
/// │  3 │ GamificationStateModel   │ one row, keyed by userId                  │
/// │  4 │ AdviceRecordModel        │ local cache, not synced                   │
/// │  5 │ PeriodAggregateModel     │ report cache, not synced                  │
/// │ 6-9│ (reserved for future models)                                        │
/// │ 10 │ TransactionType   (enum) │ hand-written adapter                      │
/// │ 11 │ TransactionSource (enum) │ hand-written adapter                      │
/// │ 12 │ BudgetPeriod      (enum) │ hand-written adapter                      │
/// │ 13 │ PeriodType        (enum) │ hand-written adapter                      │
/// │ 14 │ SyncStatus        (enum) │ hand-written adapter                      │
/// └────┴──────────────────────────┴──────────────────────────────────────────┘
///
/// Badge has no id: it is a static catalogue, never persisted (CLAUDE.md §4).
library;

class HiveTypeIds {
  const HiveTypeIds._();

  // Models
  static const int transaction = 0;
  static const int category = 1;
  static const int budget = 2;
  static const int gamificationState = 3;
  static const int adviceRecord = 4;
  static const int periodAggregate = 5;

  // Enums
  static const int transactionType = 10;
  static const int transactionSource = 11;
  static const int budgetPeriod = 12;
  static const int periodType = 13;
  static const int syncStatus = 14;
}

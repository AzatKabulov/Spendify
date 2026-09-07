/// Shared domain enums. Plain Dart — no Hive, no Firebase.
///
/// The Hive `TypeAdapter`s for these live in `data/local/models/enum_adapters.dart`
/// at reserved typeIds 10–14 (see `data/local/hive_types.dart`). The data layer
/// may import this file; this file must never import anything from `data/`.
library;

/// Whether a transaction adds to or subtracts from the balance.
/// `amountMinor` is always stored positive; direction comes from here.
enum TransactionType { income, expense }

/// How a transaction entered the app.
enum TransactionSource { manual, scanned }

/// Budgeting period a spending limit applies over.
enum BudgetPeriod { weekly, monthly }

/// Granularity of a cached report aggregate.
enum PeriodType { weekly, monthly, yearly }

/// Local-vs-remote reconciliation state for a syncable record.
/// `pending` = has local changes not yet pushed; `synced` = matches remote.
enum SyncStatus { pending, synced }

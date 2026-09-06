# `domain/repositories/`

**Abstract interfaces only.** One per aggregate: `TransactionRepository`, `CategoryRepository`, `BudgetRepository`, `GamificationStateRepository`, `AdviceRecordRepository`, `PeriodAggregateRepository`.

These describe what the app can do with data, not how. Concrete Hive-backed implementations live in `data/repositories/`; Firestore is a sync target reached through the Sync Manager, never a second implementation the UI reads from.

The mutation rules from CLAUDE.md §8 (soft delete, bump `updatedAt`, set `syncStatus = pending`, exclude `isDeleted` from queries) are enforced in the implementations so call sites cannot forget them.

_Populated in Phase 1._

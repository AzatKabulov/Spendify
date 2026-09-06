# `domain/entities/`

Plain Dart models and enums. **Nothing from `data/` or `presentation/` may be imported here, and neither may Hive, Firebase, or Gemini.** No `@HiveType` annotations — the Hive-annotated versions live in `data/local/models/` as separate DTOs, with `data/local/mappers/` converting between the two. That boilerplate is deliberate: it is what lets the storage layer be swapped without touching domain logic (CLAUDE.md §3).

Entities (Phase 1): `Transaction`, `Category`, `Budget`, `GamificationState`, `Badge`, `AdviceRecord`, `PeriodAggregate`.
Enums: `TransactionType`, `TransactionSource`, `BudgetPeriod`, `PeriodType`, `SyncStatus`.

Money is `int` in minor units (sen) with a `Minor` suffix (`amountMinor`, `limitAmountMinor`) — never `double`.

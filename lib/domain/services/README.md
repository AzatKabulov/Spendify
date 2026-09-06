# `domain/services/`

**Pure business logic. No storage imports, no UI imports, no network.** Data in, results out — so these are directly unit-testable, which the report commits to.

- `BudgetEvaluator` (Phase 3) — takes transactions + budgets, returns budget status (under / approaching ~80% / at / over).
- `GamificationEngine` (Phase 8) — takes behavioural events, returns XP / coin / badge / streak changes. Driven by events raised by the Transaction and Budget managers, never called directly from widgets. Rewards attach to healthy budgeting behaviour only — never time-in-app or app-open counts (CLAUDE.md §7).

Also home to sync conflict-resolution logic (last-write-wins on `updatedAt`) and Gemini response parsing, both of which must be pure and tested.

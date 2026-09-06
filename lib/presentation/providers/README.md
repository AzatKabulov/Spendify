# `presentation/providers/`

Riverpod providers that wire the UI to the domain layer: repository providers, view-model / notifier classes holding screen state, and derived providers (current balance, budget status, this-period aggregates).

Providers depend on `domain/` interfaces and `core/` DI — not on concrete `data/` classes directly, so implementations stay swappable. Business rules belong in `domain/services/`, not in notifiers.

_Repository providers land in Phase 1; screen notifiers from Phase 2._

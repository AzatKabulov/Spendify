# `core/`

Cross-cutting building blocks with **no feature knowledge** and **no layer above domain**.

Belongs here:
- App-wide constants (`constants.dart`) — including the Phase 1 placeholder `userId` (`local-user`) that Phase 5 migrates to the real Firebase UID.
- Error types: `Failure` hierarchy and a `Result<T>` / `Either`-style type used by repositories.
- Dependency-injection setup / provider container wiring.
- Small pure helpers shared across layers (money formatting lives at the UI boundary, not here).

Must not import from `data/` or `presentation/`. No Hive, Firebase, or Gemini imports.

_Populated from Phase 1 onward._

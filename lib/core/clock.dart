/// Injectable wall clock.
///
/// Repositories stamp `updatedAt` from a [Clock] rather than calling
/// `DateTime.now()` directly, so tests can pin time and assert conflict-
/// resolution / streak behaviour deterministically (needed from Phase 6/8).
library;

typedef Clock = DateTime Function();

/// The real clock. Returns UTC so stored timestamps are timezone-stable — the
/// UI converts to local at the display boundary.
DateTime systemClock() => DateTime.now().toUtc();

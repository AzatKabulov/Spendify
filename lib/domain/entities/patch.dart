/// Sentinel for `copyWith` on nullable fields, so callers can distinguish
/// "leave unchanged" (omit the argument) from "set to null" (pass `null`).
///
///     txn.copyWith(note: patch(null));   // clears the note
///     txn.copyWith();                    // note unchanged
library;

class Patch<T> {
  const Patch(this.value);
  final T value;
}

/// Wrap a new value (including `null`) to mark a nullable field for update.
Patch<T> patch<T>(T value) => Patch<T>(value);

/// Resolve a `Patch?` argument against the current field value.
T resolvePatch<T>(Patch<T>? p, T current) => p == null ? current : p.value;

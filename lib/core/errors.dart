/// Error types for the data layer.
///
/// Design note (Phase 1): repositories signal failure by **throwing** these
/// typed exceptions rather than returning a `Result<T>` / `Either`. Rationale:
///   - it is the idiomatic Flutter/Dart shape, and Riverpod's `AsyncValue`
///     already models loading/error at the provider boundary;
///   - CLAUDE.md §8 asks for "explicit error handling over silent catches",
///     which typed exceptions + no bare `catch` satisfies.
/// If a `Result` type is wanted later it can wrap these without touching call
/// sites. This is a deliberate, flagged deviation from the "Result type"
/// mentioned in the folder plan.
library;

/// Base class for every failure originating in local storage.
sealed class StorageException implements Exception {
  const StorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StorageException($message)${cause == null ? '' : ' <- $cause'}';
}

/// The encryption key could not be created, read, or decoded.
final class EncryptionKeyException extends StorageException {
  const EncryptionKeyException(super.message, {super.cause});
}

/// A Hive box could not be opened, and recovery (wipe + reopen) also failed.
final class BoxUnavailableException extends StorageException {
  const BoxUnavailableException(this.boxName, {Object? cause})
    : super('Box "$boxName" could not be opened', cause: cause);

  final String boxName;
}

/// A read/write against an open box failed, or the requested record is missing
/// where the caller required it to exist.
final class RecordAccessException extends StorageException {
  const RecordAccessException(super.message, {super.cause});
}

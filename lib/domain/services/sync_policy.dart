/// Pure sync policy — last-write-wins resolution, batch chunking, retry
/// backoff. No I/O, no Firestore, no `DateTime.now()`. Directly unit-testable
/// (CLAUDE.md §8: "sync conflict resolution" is called out for tests).
library;

/// Last-write-wins on `updatedAt`.
///
/// Returns `true` when the remote copy should overwrite the local one:
/// strictly `remote.updatedAt > local.updatedAt`. **Equal timestamps keep
/// local** — arbitrary but deterministic, and it means a record that already
/// round-tripped (same `updatedAt` on both sides) is never needlessly
/// rewritten.
///
/// CLOCK SKEW: `updatedAt` is device wall-clock and can be wrong. The gateway
/// also stores a Firestore `serverSyncedAt` for debugging, but LWW stays on the
/// device `updatedAt` so the exact same rule works offline. This is a known
/// limitation of single-user LWW, acceptable for the report's single-device
/// scope (§1.4.3).
bool remoteWins({
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
}) => remoteUpdatedAt.isAfter(localUpdatedAt);

/// Split [items] into chunks of at most [maxPerChunk] (Firestore's write-batch
/// limit is 500 operations). An empty input yields no chunks.
List<List<T>> chunkForBatch<T>(List<T> items, {int maxPerChunk = 500}) {
  assert(maxPerChunk > 0, 'maxPerChunk must be positive');
  if (items.isEmpty) return const [];
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += maxPerChunk) {
    chunks.add(
      items.sublist(
        i,
        i + maxPerChunk > items.length ? items.length : i + maxPerChunk,
      ),
    );
  }
  return chunks;
}

/// Exponential backoff for retryable sync failures: ~2s, 4s, 8s, 16s, … capped
/// at [cap] (~5 min). [attempt] is 1-based (first retry == 1).
Duration backoffDelay(
  int attempt, {
  Duration base = const Duration(seconds: 2),
  Duration cap = const Duration(minutes: 5),
}) {
  if (attempt < 1) return Duration.zero;
  // 2s * 2^(attempt-1). Guard the shift so a large attempt can't overflow.
  final exp = attempt > 20 ? (1 << 20) : (1 << (attempt - 1));
  final millis = base.inMilliseconds * exp;
  return millis >= cap.inMilliseconds ? cap : Duration(milliseconds: millis);
}

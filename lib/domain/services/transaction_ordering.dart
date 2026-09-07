import '../entities/transaction.dart';

/// The order transactions are shown to the user: newest transaction date
/// first, and for entries on the same day the most recently created one first.
///
/// Pure and total, so the list ordering is unit-tested independently of the
/// widget (CLAUDE.md §8).
int compareTransactionsForDisplay(Transaction a, Transaction b) {
  final byDate = b.date.compareTo(a.date);
  if (byDate != 0) return byDate;
  final byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) return byCreated;
  // Final tie-breaker so the sort is stable/deterministic across platforms.
  return a.id.compareTo(b.id);
}

/// Returns a new list sorted by [compareTransactionsForDisplay]. Does not
/// mutate the input.
List<Transaction> sortTransactionsForDisplay(Iterable<Transaction> source) {
  final list = source.toList();
  list.sort(compareTransactionsForDisplay);
  return list;
}

import 'advice_item.dart';

/// A cached set of AI advice items. **Not a [Syncable]** (CLAUDE.md §4): advice
/// is regenerable from local data, so it is never pushed to Firestore and has
/// no tombstone. [summaryHash] is the hash of the aggregate summary that was
/// sent to Gemini — used to skip regenerating advice for unchanged data
/// (Phase 9).
class AdviceRecord {
  const AdviceRecord({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.summaryHash,
    required this.adviceItems,
  });

  final String id;
  final String userId;
  final DateTime generatedAt;
  final String summaryHash;

  /// Phase 9: was `List<String>`; now structured (see [AdviceItem]).
  final List<AdviceItem> adviceItems;

  AdviceRecord copyWith({
    DateTime? generatedAt,
    String? summaryHash,
    List<AdviceItem>? adviceItems,
  }) {
    return AdviceRecord(
      id: id,
      userId: userId,
      generatedAt: generatedAt ?? this.generatedAt,
      summaryHash: summaryHash ?? this.summaryHash,
      adviceItems: adviceItems ?? this.adviceItems,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdviceRecord &&
      other.id == id &&
      other.userId == userId &&
      other.generatedAt == generatedAt &&
      other.summaryHash == summaryHash &&
      _listEquals(other.adviceItems, adviceItems);

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    generatedAt,
    summaryHash,
    Object.hashAll(adviceItems),
  );

  @override
  String toString() =>
      'AdviceRecord($id, ${adviceItems.length} items, hash=$summaryHash)';
}

bool _listEquals(List<AdviceItem> a, List<AdviceItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

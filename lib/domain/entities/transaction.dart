import 'enums.dart';
import 'patch.dart';
import 'syncable.dart';

/// A single income or expense entry. Immutable; mutate via [copyWith] or the
/// [Syncable] transforms.
///
/// `amountMinor` is in sen (1/100 MYR) and always positive — direction is
/// [type]. Money is never a `double` (CLAUDE.md §4).
class Transaction implements Syncable<Transaction> {
  const Transaction({
    required this.id,
    required this.userId,
    required this.amountMinor,
    required this.type,
    required this.categoryId,
    required this.date,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  }) : assert(amountMinor >= 0, 'amountMinor must be non-negative');

  /// New manual/scanned transaction. `createdAt` and `updatedAt` are set to
  /// [now]; `syncStatus` starts `pending`.
  factory Transaction.create({
    required String id,
    required String userId,
    required int amountMinor,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    required DateTime now,
    TransactionSource source = TransactionSource.manual,
    String? note,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      amountMinor: amountMinor,
      type: type,
      categoryId: categoryId,
      date: date,
      source: source,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  final String id;
  @override
  final String userId;
  final int amountMinor;
  final TransactionType type;
  final String categoryId;

  /// User-editable transaction date (distinct from [createdAt]).
  final DateTime date;
  final String? note;
  final TransactionSource source;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  Transaction copyWith({
    int? amountMinor,
    TransactionType? type,
    String? categoryId,
    DateTime? date,
    Patch<String?>? note,
    TransactionSource? source,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      amountMinor: amountMinor ?? this.amountMinor,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: resolvePatch(note, this.note),
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Transaction markUpdated({required DateTime at}) =>
      copyWith(updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Transaction markDeleted({required DateTime at}) =>
      copyWith(isDeleted: true, updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Transaction markSynced() => copyWith(syncStatus: SyncStatus.synced);

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.userId == userId &&
      other.amountMinor == amountMinor &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.date == date &&
      other.note == note &&
      other.source == source &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.isDeleted == isDeleted &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    amountMinor,
    type,
    categoryId,
    date,
    note,
    source,
    createdAt,
    updatedAt,
    isDeleted,
    syncStatus,
  );

  @override
  String toString() =>
      'Transaction($id, ${type.name} $amountMinor, cat=$categoryId, '
      'deleted=$isDeleted, sync=${syncStatus.name})';
}

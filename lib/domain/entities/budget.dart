import 'enums.dart';
import 'patch.dart';
import 'syncable.dart';

/// A spending limit. `categoryId == null` means an overall limit across all
/// categories. `limitAmountMinor` is in sen.
class Budget implements Syncable<Budget> {
  const Budget({
    required this.id,
    required this.userId,
    required this.limitAmountMinor,
    required this.period,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  }) : assert(limitAmountMinor >= 0, 'limitAmountMinor must be non-negative');

  factory Budget.create({
    required String id,
    required String userId,
    required int limitAmountMinor,
    required BudgetPeriod period,
    required DateTime startDate,
    required DateTime now,
    String? categoryId,
  }) {
    return Budget(
      id: id,
      userId: userId,
      limitAmountMinor: limitAmountMinor,
      period: period,
      startDate: startDate,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  final String id;
  @override
  final String userId;

  /// `null` = overall budget across every category.
  final String? categoryId;
  final int limitAmountMinor;
  final BudgetPeriod period;
  final DateTime startDate;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  bool get isOverall => categoryId == null;

  Budget copyWith({
    Patch<String?>? categoryId,
    int? limitAmountMinor,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Budget(
      id: id,
      userId: userId,
      categoryId: resolvePatch(categoryId, this.categoryId),
      limitAmountMinor: limitAmountMinor ?? this.limitAmountMinor,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Budget markUpdated({required DateTime at}) =>
      copyWith(updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Budget markDeleted({required DateTime at}) =>
      copyWith(isDeleted: true, updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Budget markRestored({required DateTime at}) =>
      copyWith(isDeleted: false, updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Budget markSynced() => copyWith(syncStatus: SyncStatus.synced);

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.id == id &&
      other.userId == userId &&
      other.categoryId == categoryId &&
      other.limitAmountMinor == limitAmountMinor &&
      other.period == period &&
      other.startDate == startDate &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.isDeleted == isDeleted &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    categoryId,
    limitAmountMinor,
    period,
    startDate,
    createdAt,
    updatedAt,
    isDeleted,
    syncStatus,
  );

  @override
  String toString() =>
      'Budget($id, ${period.name} $limitAmountMinor, '
      'cat=${categoryId ?? "ALL"}, deleted=$isDeleted)';
}

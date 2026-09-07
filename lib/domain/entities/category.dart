import 'enums.dart';
import 'syncable.dart';

/// A spending/income category. `iconCode` is a Material `IconData.codePoint`;
/// `colorValue` is an ARGB `int` (`Color.value`). Both resolved to Flutter
/// types only at the UI boundary.
class Category implements Syncable<Category> {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  factory Category.create({
    required String id,
    required String userId,
    required String name,
    required int iconCode,
    required int colorValue,
    required DateTime now,
    bool isDefault = false,
  }) {
    return Category(
      id: id,
      userId: userId,
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  final String id;
  @override
  final String userId;
  final String name;
  final int iconCode;
  final int colorValue;

  /// Seeded default vs user-created. Defaults may be hidden but not hard-removed.
  final bool isDefault;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  Category copyWith({
    String? name,
    int? iconCode,
    int? colorValue,
    bool? isDefault,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Category(
      id: id,
      userId: userId,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Category markUpdated({required DateTime at}) =>
      copyWith(updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Category markDeleted({required DateTime at}) =>
      copyWith(isDeleted: true, updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Category markRestored({required DateTime at}) =>
      copyWith(isDeleted: false, updatedAt: at, syncStatus: SyncStatus.pending);

  @override
  Category markSynced() => copyWith(syncStatus: SyncStatus.synced);

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.iconCode == iconCode &&
      other.colorValue == colorValue &&
      other.isDefault == isDefault &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.isDeleted == isDeleted &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    iconCode,
    colorValue,
    isDefault,
    createdAt,
    updatedAt,
    isDeleted,
    syncStatus,
  );

  @override
  String toString() =>
      'Category($id, "$name", default=$isDefault, deleted=$isDeleted)';
}

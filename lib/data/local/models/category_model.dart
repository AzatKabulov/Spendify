import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

part 'category_model.g.dart';

/// Hive persistence form of `domain/entities/Category`.
@HiveType(typeId: HiveTypeIds.category)
class CategoryModel {
  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.syncStatus,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String name;

  @HiveField(3)
  int iconCode;

  @HiveField(4)
  int colorValue;

  @HiveField(5)
  bool isDefault;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  bool isDeleted;

  @HiveField(9)
  SyncStatus syncStatus;
}

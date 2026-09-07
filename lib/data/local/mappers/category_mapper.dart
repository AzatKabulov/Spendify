import '../../../domain/entities/category.dart';
import '../models/category_model.dart';

extension CategoryModelMapper on CategoryModel {
  Category toDomain() => Category(
    id: id,
    userId: userId,
    name: name,
    iconCode: iconCode,
    colorValue: colorValue,
    isDefault: isDefault,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

extension CategoryEntityMapper on Category {
  CategoryModel toModel() => CategoryModel(
    id: id,
    userId: userId,
    name: name,
    iconCode: iconCode,
    colorValue: colorValue,
    isDefault: isDefault,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

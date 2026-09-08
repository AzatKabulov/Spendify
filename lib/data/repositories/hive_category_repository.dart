import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../local/mappers/category_mapper.dart';
import '../local/models/category_model.dart';
import 'base_syncable_hive_repository.dart';
import 'default_categories.dart';

class HiveCategoryRepository
    extends BaseSyncableHiveRepository<Category, CategoryModel>
    implements CategoryRepository {
  HiveCategoryRepository(
    super.box, {
    required Box<dynamic> metaBox,
    required super.userId,
    super.clock,
    IdGenerator idGenerator = generateUuidV4,
  }) : _meta = metaBox,
       _newId = idGenerator;

  final Box<dynamic> _meta;
  final IdGenerator _newId;

  @override
  CategoryModel toModel(Category entity) => entity.toModel();

  @override
  Category toDomain(CategoryModel model) => model.toDomain();

  @override
  Future<void> ensureDefaultsSeeded() async {
    final alreadySeeded =
        _meta.get(MetaKeys.defaultCategoriesSeeded, defaultValue: false)
            as bool;
    if (alreadySeeded) return;

    final now = nowUtc();
    for (final seed in kDefaultCategories) {
      final category = Category.create(
        id: _newId(),
        userId: userId,
        name: seed.name,
        iconCode: seed.iconCode,
        colorValue: seed.colorValue,
        now: now,
        isDefault: true,
      );
      await box.put(category.id, toModel(category));
    }

    await _meta.put(MetaKeys.defaultCategoriesSeeded, true);
  }
}

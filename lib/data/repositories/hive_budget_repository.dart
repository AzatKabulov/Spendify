import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../local/mappers/budget_mapper.dart';
import '../local/models/budget_model.dart';
import 'base_syncable_hive_repository.dart';

class HiveBudgetRepository
    extends BaseSyncableHiveRepository<Budget, BudgetModel>
    implements BudgetRepository {
  HiveBudgetRepository(super.box, {required super.userId, super.clock});

  @override
  BudgetModel toModel(Budget entity) => entity.toModel();

  @override
  Budget toDomain(BudgetModel model) => model.toDomain();

  @override
  Future<Budget?> getOverall() async {
    final all = await getAll();
    for (final budget in all) {
      if (budget.isOverall) return budget;
    }
    return null;
  }

  @override
  Future<Budget?> getForCategory(String categoryId) async {
    final all = await getAll();
    for (final budget in all) {
      if (budget.categoryId == categoryId) return budget;
    }
    return null;
  }
}

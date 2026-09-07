import '../../../domain/entities/budget.dart';
import '../models/budget_model.dart';

extension BudgetModelMapper on BudgetModel {
  Budget toDomain() => Budget(
    id: id,
    userId: userId,
    categoryId: categoryId,
    limitAmountMinor: limitAmountMinor,
    period: period,
    startDate: startDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

extension BudgetEntityMapper on Budget {
  BudgetModel toModel() => BudgetModel(
    id: id,
    userId: userId,
    categoryId: categoryId,
    limitAmountMinor: limitAmountMinor,
    period: period,
    startDate: startDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

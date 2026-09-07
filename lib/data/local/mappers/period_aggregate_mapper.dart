import '../../../domain/entities/period_aggregate.dart';
import '../models/period_aggregate_model.dart';

extension PeriodAggregateModelMapper on PeriodAggregateModel {
  PeriodAggregate toDomain() => PeriodAggregate(
    id: id,
    userId: userId,
    periodType: periodType,
    periodKey: periodKey,
    categoryId: categoryId,
    totalIncomeMinor: totalIncomeMinor,
    totalExpenseMinor: totalExpenseMinor,
    transactionCount: transactionCount,
    updatedAt: updatedAt,
  );
}

extension PeriodAggregateEntityMapper on PeriodAggregate {
  PeriodAggregateModel toModel() => PeriodAggregateModel(
    id: id,
    userId: userId,
    periodType: periodType,
    periodKey: periodKey,
    categoryId: categoryId,
    totalIncomeMinor: totalIncomeMinor,
    totalExpenseMinor: totalExpenseMinor,
    transactionCount: transactionCount,
    updatedAt: updatedAt,
  );
}

import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

part 'period_aggregate_model.g.dart';

/// Hive persistence form of `domain/entities/PeriodAggregate`. Report cache
/// only — rebuilt from transactions, never synced.
@HiveType(typeId: HiveTypeIds.periodAggregate)
class PeriodAggregateModel {
  PeriodAggregateModel({
    required this.id,
    required this.userId,
    required this.periodType,
    required this.periodKey,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.transactionCount,
    required this.updatedAt,
    this.categoryId,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  PeriodType periodType;

  @HiveField(3)
  String periodKey;

  /// `null` = across all categories.
  @HiveField(4)
  String? categoryId;

  @HiveField(5)
  int totalIncomeMinor;

  @HiveField(6)
  int totalExpenseMinor;

  @HiveField(7)
  int transactionCount;

  @HiveField(8)
  DateTime updatedAt;
}

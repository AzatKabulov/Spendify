import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

part 'budget_model.g.dart';

/// Hive persistence form of `domain/entities/Budget`.
@HiveType(typeId: HiveTypeIds.budget)
class BudgetModel {
  BudgetModel({
    required this.id,
    required this.userId,
    required this.limitAmountMinor,
    required this.period,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.syncStatus,
    this.categoryId,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  /// `null` = overall budget.
  @HiveField(2)
  String? categoryId;

  @HiveField(3)
  int limitAmountMinor;

  @HiveField(4)
  BudgetPeriod period;

  @HiveField(5)
  DateTime startDate;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  bool isDeleted;

  @HiveField(9)
  SyncStatus syncStatus;
}

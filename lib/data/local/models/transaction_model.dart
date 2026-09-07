import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

part 'transaction_model.g.dart';

/// Hive persistence form of `domain/entities/Transaction`. Field numbers are
/// permanent — add new fields with new numbers, never renumber or reuse.
@HiveType(typeId: HiveTypeIds.transaction)
class TransactionModel {
  TransactionModel({
    required this.id,
    required this.userId,
    required this.amountMinor,
    required this.type,
    required this.categoryId,
    required this.date,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.syncStatus,
    this.note,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  int amountMinor;

  @HiveField(3)
  TransactionType type;

  @HiveField(4)
  String categoryId;

  @HiveField(5)
  DateTime date;

  @HiveField(6)
  String? note;

  @HiveField(7)
  TransactionSource source;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  bool isDeleted;

  @HiveField(11)
  SyncStatus syncStatus;
}

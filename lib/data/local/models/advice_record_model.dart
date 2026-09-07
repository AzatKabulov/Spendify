import 'package:hive/hive.dart';

import '../hive_types.dart';

part 'advice_record_model.g.dart';

/// Hive persistence form of `domain/entities/AdviceRecord`. Local cache only.
@HiveType(typeId: HiveTypeIds.adviceRecord)
class AdviceRecordModel {
  AdviceRecordModel({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.summaryHash,
    required this.adviceItems,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  DateTime generatedAt;

  @HiveField(3)
  String summaryHash;

  @HiveField(4)
  List<String> adviceItems;
}

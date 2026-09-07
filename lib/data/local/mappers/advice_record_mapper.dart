import '../../../domain/entities/advice_record.dart';
import '../models/advice_record_model.dart';

extension AdviceRecordModelMapper on AdviceRecordModel {
  AdviceRecord toDomain() => AdviceRecord(
    id: id,
    userId: userId,
    generatedAt: generatedAt,
    summaryHash: summaryHash,
    adviceItems: List<String>.unmodifiable(adviceItems),
  );
}

extension AdviceRecordEntityMapper on AdviceRecord {
  AdviceRecordModel toModel() => AdviceRecordModel(
    id: id,
    userId: userId,
    generatedAt: generatedAt,
    summaryHash: summaryHash,
    adviceItems: List<String>.from(adviceItems),
  );
}

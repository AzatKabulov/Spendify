import 'package:hive/hive.dart';

import '../../domain/entities/advice_record.dart';
import '../../domain/repositories/advice_record_repository.dart';
import '../local/mappers/advice_record_mapper.dart';
import '../local/models/advice_record_model.dart';

/// Local-only cache of generated advice. Keyed by [AdviceRecord.id].
class HiveAdviceRecordRepository implements AdviceRecordRepository {
  HiveAdviceRecordRepository(this._box);

  final Box<AdviceRecordModel> _box;

  @override
  Future<AdviceRecord?> getLatest() async {
    AdviceRecordModel? latest;
    for (final record in _box.values) {
      if (latest == null || record.generatedAt.isAfter(latest.generatedAt)) {
        latest = record;
      }
    }
    return latest?.toDomain();
  }

  @override
  Future<AdviceRecord?> getBySummaryHash(String summaryHash) async {
    for (final record in _box.values) {
      if (record.summaryHash == summaryHash) return record.toDomain();
    }
    return null;
  }

  @override
  Future<AdviceRecord> save(AdviceRecord record) async {
    await _box.put(record.id, record.toModel());
    return record;
  }

  @override
  Future<void> clear() => _box.clear();
}

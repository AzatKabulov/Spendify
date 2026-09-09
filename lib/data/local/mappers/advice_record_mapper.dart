import 'dart:convert';

import '../../../domain/entities/advice_item.dart';
import '../../../domain/entities/advice_record.dart';
import '../models/advice_record_model.dart';

/// The Hive model keeps `adviceItems` as `List<String>` (no schema change from
/// Phase 1); each string is a JSON object `{"title","body"}`. A legacy plain
/// string (pre-Phase-9) is read as a body-only item.
extension AdviceRecordModelMapper on AdviceRecordModel {
  AdviceRecord toDomain() => AdviceRecord(
    id: id,
    userId: userId,
    generatedAt: generatedAt,
    summaryHash: summaryHash,
    adviceItems: List<AdviceItem>.unmodifiable(
      adviceItems.map(_itemFromStored),
    ),
  );
}

extension AdviceRecordEntityMapper on AdviceRecord {
  AdviceRecordModel toModel() => AdviceRecordModel(
    id: id,
    userId: userId,
    generatedAt: generatedAt,
    summaryHash: summaryHash,
    adviceItems: adviceItems
        .map((i) => jsonEncode(i.toJson()))
        .toList(growable: false),
  );
}

AdviceItem _itemFromStored(String stored) {
  try {
    final decoded = jsonDecode(stored);
    if (decoded is Map<String, Object?>) return AdviceItem.fromJson(decoded);
  } catch (_) {
    // not JSON — a legacy flat string
  }
  return AdviceItem(title: '', body: stored);
}

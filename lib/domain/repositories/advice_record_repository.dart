import '../entities/advice_record.dart';

/// Storage contract for cached [AdviceRecord]s. Local-only (not synced): advice
/// is regenerable, so there is no tombstone or sync status.
abstract interface class AdviceRecordRepository {
  /// The most recently generated advice for the current user, or `null`.
  Future<AdviceRecord?> getLatest();

  /// An advice record previously cached for exactly this summary hash, or
  /// `null` — used in Phase 9 to avoid a redundant Gemini call.
  Future<AdviceRecord?> getBySummaryHash(String summaryHash);

  /// Persist a freshly generated record.
  Future<AdviceRecord> save(AdviceRecord record);

  /// Drop cached advice (Phase 10 "clear cached advice" setting).
  Future<void> clear();
}

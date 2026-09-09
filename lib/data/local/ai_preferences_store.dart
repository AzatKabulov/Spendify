import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../domain/entities/ai_consent.dart';

/// Persists the AI consent decision (Phase 10). Device-level, not synced —
/// backed by the encrypted `spendly_meta` box. Reads are synchronous so a
/// Riverpod `Notifier.build()` can consult it directly.
abstract interface class AiPreferencesStore {
  AiConsent get consent;
  Future<void> setConsent(AiConsent value);
}

class HiveAiPreferencesStore implements AiPreferencesStore {
  HiveAiPreferencesStore(this._meta);

  final Box<dynamic> _meta;

  @override
  AiConsent get consent => switch (_meta.get(MetaKeys.aiConsent)) {
    'granted' => AiConsent.granted,
    'denied' => AiConsent.denied,
    _ => AiConsent.undecided,
  };

  @override
  Future<void> setConsent(AiConsent value) => switch (value) {
    AiConsent.granted => _meta.put(MetaKeys.aiConsent, 'granted'),
    AiConsent.denied => _meta.put(MetaKeys.aiConsent, 'denied'),
    AiConsent.undecided => _meta.delete(MetaKeys.aiConsent),
  };
}

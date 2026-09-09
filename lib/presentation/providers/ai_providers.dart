import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gemini_config.dart';
import '../../data/local/ai_preferences_store.dart';
import '../../domain/entities/ai_consent.dart';
import 'repository_providers.dart';

/// The Gemini API key, supplied at build time via `--dart-define` (CLAUDE.md
/// §9). Empty = no key on this build. Overridable in tests. Both AI features
/// share this one key path.
final geminiApiKeyProvider = Provider<String>((ref) => kGeminiApiKey);

/// AI consent store (Phase 10). Overridable in tests.
final aiPreferencesStoreProvider = Provider<AiPreferencesStore>(
  (ref) => HiveAiPreferencesStore(ref.watch(hiveStoreProvider).meta),
);

/// The user's current AI consent decision. `grant()` / `revoke()` persist and
/// update it; the AI feature gates and the consent-screen route watch it.
final aiConsentProvider = NotifierProvider<AiConsentController, AiConsent>(
  AiConsentController.new,
);

class AiConsentController extends Notifier<AiConsent> {
  @override
  AiConsent build() => ref.watch(aiPreferencesStoreProvider).consent;

  Future<void> grant() => _set(AiConsent.granted);

  /// Turning AI off in settings, or declining on the consent screen.
  Future<void> revoke() => _set(AiConsent.denied);

  Future<void> _set(AiConsent value) async {
    await ref.read(aiPreferencesStoreProvider).setConsent(value);
    state = value;
  }
}

/// `true` when a Gemini API key is present on this build. AI cannot work
/// without it regardless of consent.
final aiKeyPresentProvider = Provider<bool>(
  (ref) => ref.watch(geminiApiKeyProvider).isNotEmpty,
);

/// The master AI gate: a key is present **and** the user has granted consent.
/// When `false`, no Gemini client is constructed and no AI entry point shows.
final aiFeaturesEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(aiKeyPresentProvider) &&
      ref.watch(aiConsentProvider) == AiConsent.granted,
);

/// `true` when the first-run consent screen must be shown before the app
/// proceeds — a key is present and the user has not decided yet.
final aiConsentRequiredProvider = Provider<bool>(
  (ref) =>
      ref.watch(aiKeyPresentProvider) &&
      ref.watch(aiConsentProvider) == AiConsent.undecided,
);

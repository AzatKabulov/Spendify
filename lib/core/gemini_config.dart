/// Gemini API key, supplied at build time — **never** committed to source
/// (CLAUDE.md §8):
///
///     flutter run --dart-define=GEMINI_API_KEY=AIza...
///     flutter build apk --release --dart-define=GEMINI_API_KEY=AIza...
///
/// (or `--dart-define-from-file=secrets.json` with `secrets.json` gitignored).
///
/// **OPEN DECISION — CLAUDE.md §9, still pending.** This constant is the
/// mechanism for *option B* (client-side key with API restrictions, documented
/// as a known limitation). *Option A* (proxy through a Firebase Cloud Function
/// so the key never ships in the APK) would instead point
/// `GeminiReceiptClient`'s endpoint at the function URL and leave this empty.
/// Decide with the supervisor before the CP2 submission and record it in §9.
library;

const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Which Gemini model the receipt scanner calls. Bump when a newer flash model
/// ships.
const String kGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-2.0-flash',
);

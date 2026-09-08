# Gemini receipt scanner setup (Phase 7)

The scanner code is done and unit-tested. To make it run you need a Gemini API
key. **The key must never be committed** (CLAUDE.md §8).

## Key placement — decide this with your supervisor (CLAUDE.md §9)

Phase 7 built **option B** (client-side key), because option A (Cloud Function
proxy) needs the Blaze plan and a deployed function. This is *provisional*:

- **Staying with B:** in Google Cloud Console → APIs & Services → Credentials,
  restrict the key to (1) Android apps — package `com.azatkabulov.spendly` +
  your signing SHA-1, and (2) the *Generative Language API* only. Document it
  as a known limitation in the CP2 report.
- **Moving to A later:** deploy a Cloud Function that holds the key and calls
  Gemini, then point `GeminiReceiptClient`'s `endpoint` at the function URL and
  pass an empty key. Nothing above `data/remote/gemini_client.dart` changes.

## Get a key

1. <https://aistudio.google.com/app/apikey> → **Create API key**.
2. (Recommended) attach it to the same Google Cloud project as Firebase.

## Run with the key

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...你的key
flutter build apk --release --dart-define=GEMINI_API_KEY=AIza...
```

Or keep it in a gitignored file and pass the whole set:

```bash
# secrets.json  (gitignored)
{ "GEMINI_API_KEY": "AIza..." }

flutter run --dart-define-from-file=secrets.json
```

Without the key, the "Scan receipt" button simply doesn't appear — the rest of
the app is unaffected.

## Verify (Phase 7 "done when")

- Scan ~10 real receipts (printed, phone-screen, crumpled, dim). Record how
  many gave a usable merchant / amount / date — this honest number is CP2
  evidence.
- A blank-wall photo falls back to the manual form, no crash.
- Scan a receipt, then back out without tapping Save — nothing is saved.
- Confirm the temp image file is gone after both a successful scan and a
  cancel.
- Airplane mode: the scan flow says it needs internet; everything else works.
- `git grep -i AIza` and `git grep GEMINI_API_KEY` in tracked files → nothing.

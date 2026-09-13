# Spendly

**AI-powered, offline-first Android budgeting app for students and young adults
in Malaysia.** Final-year capstone project (Capstone Project 2).

Spendly automates expense recording with AI receipt scanning, works fully
offline for every core feature, and uses gamification plus AI-generated advice
to sustain long-term engagement — without the compulsive-checking patterns that
usually come with it.

---

## What it does

| Feature | Notes |
|---|---|
| Manual transactions | amount, type, category, date, optional note; today + last category pre-filled |
| Receipt scanning | photo → Gemini extracts amount/date/merchant → **you confirm every field** before it saves |
| Custom categories | create / edit / delete, with icon + colour; defaults are seeded and locked |
| Budgets | per-category or overall, weekly or monthly, with "approaching" and "exceeded" warnings |
| Reports | weekly / monthly / yearly, from a cached aggregate table (never a full re-scan) |
| Gamification | XP, coins, levels, badges and login streaks — rewards *budgeting behaviour*, not app opens |
| AI advice | personalised suggestions from an **aggregated, rounded** summary of your own spending |
| Sync | local Hive is the source of truth; Firestore is an opportunistic backup/restore target |

Everything above works with **zero connectivity** except the two AI features,
which degrade gracefully (clear message, manual fallback, last cached advice).

---

## Tech stack

| Layer | Choice |
|---|---|
| Client | Flutter (Dart), **Android only** |
| Local storage | Hive, AES-encrypted; key in the Android Keystore via `flutter_secure_storage` |
| Backend | Firebase — Authentication + Cloud Firestore (backup target only) |
| AI | Google Gemini (one key, one model — receipt OCR *and* text advice) |
| State | Riverpod |
| Charts | fl_chart |

The stack is fixed by the project proposal — see [CLAUDE.md](CLAUDE.md) §2.

---

## Architecture in one paragraph

Three layers — **presentation** (Flutter + Riverpod), **domain** (pure entities,
repository interfaces and logic services), **data** (Hive, Firebase, Gemini,
repository implementations). Dependencies point inward: `domain/` imports
nothing from `data/`. Hive is the single source of truth; the UI never reads a
Firestore stream. Reports and budgets read a maintained `PeriodAggregate` cache,
so they stay O(periods) rather than O(transactions) as history grows.

Full detail, data flow and a diagram: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

```
lib/
  core/         constants, typed errors, money utils, theme, dev seeds
  domain/
    entities/     plain Dart models (no Hive, no Firebase)
    repositories/ abstract interfaces + typed exceptions
    services/     BudgetEvaluator, GamificationEngine, AggregationService … (pure)
  data/
    local/        Hive boxes, type adapters, mappers, secure key
    remote/       Firebase + Gemini clients
    repositories/ implementations, Sync Manager, aggregate maintenance
  presentation/
    screens/  widgets/  providers/
```

---

## Running it

### Prerequisites

- Flutter 3.44.x (stable), Dart 3.12+
- Android SDK, an emulator or a device on **Android 7.0 (API 24)** or newer
- JDK 21 (Temurin) — `flutter config --jdk-dir` if `flutter doctor` can't find it

### First run (no backend needed)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Hive adapters
flutter run
```

The app builds and runs with **no Firebase and no Gemini key**. Sign-in shows
"not available in this build", and the AI entry points are hidden. Every other
feature works.

### Enabling the backend and AI (optional)

| To enable | Do this | Guide |
|---|---|---|
| Sign-in + cloud backup | create a Firebase project, run `flutterfire configure` | [FIREBASE_SETUP.md](FIREBASE_SETUP.md) |
| Receipt scan + AI advice | get a Gemini API key, pass `--dart-define=GEMINI_API_KEY=…` | [AI_SETUP.md](AI_SETUP.md) |

```bash
# with AI enabled:
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Neither `google-services.json`, `firebase_options.dart`, nor the Gemini key is
committed — all are gitignored from Phase 0 (CLAUDE.md §8).

---

## Tests

```bash
flutter analyze                       # static analysis — kept clean
flutter test                          # unit + widget + journey (~380 tests)
flutter test --coverage               # writes coverage/lcov.info
flutter test test/performance/        # Dart-VM performance scaling test
flutter test --tags perf              # (same, explicit)
```

On-device integration tests (need a running device/emulator):

```bash
flutter test integration_test/performance_test.dart      # core-action timings, 5000 txns
```

Measured evidence against the non-functional requirements — performance, offline
reliability, security, coverage, usability materials — is in
**[docs/TEST_RESULTS.md](docs/TEST_RESULTS.md)**.

---

## Release build

Release signing is configured in [android/app/build.gradle.kts](android/app/build.gradle.kts)
and reads `android/key.properties` (gitignored). R8 shrinking + obfuscation is on;
keep rules are in [android/app/proguard-rules.pro](android/app/proguard-rules.pro).

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key_here
```

If `android/key.properties` is missing (fresh clone), the release build falls
back to debug signing so it still completes — it just isn't shippably signed.
Regenerating the keystore: see [docs/RELEASE.md](docs/RELEASE.md).

---

## Project docs

| Doc | What |
|---|---|
| [CLAUDE.md](CLAUDE.md) | authoritative project brief + open decisions |
| [SPENDLY_BUILD_PLAN.md](SPENDLY_BUILD_PLAN.md) | phase-by-phase build plan |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | layers, components, data flow, diagram |
| [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md) | NFR evidence pack (CP2 §3.2.2) |
| [docs/MANUAL_TEST_CHECKLIST.md](docs/MANUAL_TEST_CHECKLIST.md) | everything left that needs a live service, a device, or a person |
| [docs/USABILITY_TEST_PROTOCOL.md](docs/USABILITY_TEST_PROTOCOL.md) | 60-second first-transaction test — run with real participants |
| [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md) | live demo run sheet |
| [docs/RELEASE.md](docs/RELEASE.md) | signing, keystore, R8, APK checklist |
| [docs/PHASE_LOG.md](docs/PHASE_LOG.md) | what shipped in each phase |
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) / [AI_SETUP.md](AI_SETUP.md) | backend + AI key setup |

# Developing Spendify

Spendify is an Android-only Flutter application. Its local storage and core workflows can be developed without configuring Firebase or Gemini. Use the locked dependencies and preserve the presentation/domain/data boundaries described in [ARCHITECTURE.md](ARCHITECTURE.md).

## Environment

- Flutter 3.44.x with Dart 3.12.2 or newer.
- Android SDK and an Android 7.0 / API 24+ emulator or device.
- A Java runtime compatible with the Android Gradle build. The project was originally built with JDK 21; inspect `flutter doctor -v` to see which Java installation Flutter selects.

The Android package remains `com.azatkabulov.spendly`, from the app's previous name. This is an installation and service-configuration identifier; changing the display name does not require changing it. Keep it aligned with any Firebase configuration and signing identity.

## First checkout

From the repository root:

```sh
flutter pub get --enforce-lockfile
cp lib/firebase_options.example.dart lib/firebase_options.dart
flutter analyze
flutter test
```

On PowerShell use `Copy-Item` in place of `cp`. Do not overwrite an existing Firebase options file. The placeholder makes local checks possible and is recognized by `firebase_bootstrap.dart`, which returns `notConfigured` without initializing Firebase.

Generated Hive adapters (`*.g.dart`) are tracked. You do not need to regenerate them on every checkout. After changing a local Hive model, run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Review generated changes with their model changes. Keep `pubspec.lock` committed and avoid unrelated package upgrades.

## Preview with sample records

Use a fresh emulator, select its identifier from `flutter devices`, then:

```sh
flutter run -d <android-device-id> --dart-define=DEMO_SEED=true
```

The seed adds about four months of transactions, three budget states and sample rewards. It uses a local demo session only when seeding an empty database without a persisted session. It does nothing when transactions already exist and is disabled in release mode. Do not delete your own records to create screenshots; use a separate emulator or install.

Run without the demo flag for the normal sign-in flow. A real session needs Firebase configuration; the [Firebase guide](../FIREBASE_SETUP.md) covers Authentication, Firestore and rules. [AI setup](../AI_SETUP.md) covers the optional shared Gemini key and consent flow.

## Verification commands

```sh
flutter analyze
flutter test
flutter test --coverage
flutter test test/dev/demo_seed_test.dart --dart-define=DEMO_SEED=true
flutter test test/performance/
```

The regular suite skips the demo-seed test unless its compile-time flag is supplied. Run that test separately with the flag. The performance tests measure their current environment; they do not establish physical-device performance.

For the on-device performance integration check:

```sh
flutter test integration_test/performance_test.dart -d <android-device-id>
```

For a debug APK without service credentials:

```sh
flutter build apk --debug --dart-define=DEMO_SEED=true
```

The output is `build/app/outputs/flutter-apk/app-debug.apk`. Google Services processing is applied only when `android/app/google-services.json` is present. Real Firebase builds should use the generated options and Android configuration from the same project.

For release signing and R8, follow [RELEASE.md](RELEASE.md). A release build without `android/key.properties` falls back to debug signing and is not a distribution-ready release. Demo seeding is inactive in release builds regardless of the flag.

## Changes and review

Keep a change focused and include a short explanation of the problem and resulting behavior. Run the checks relevant to it, including the full unit/widget suite for logic changes. Add screenshots for visible UI changes and name the build mode and dataset used.

Core rules:

- Store money in integer minor units and keep business logic out of widgets.
- Write locally before attempting sync; sync failures must not block local writes.
- Preserve tombstones, ownership checks, operation timestamps and aggregate consistency.
- Keep AI optional, consent-gated and explicit about what data leaves the device.
- Do not commit real configuration, signing material, API keys, local financial data or generated build outputs.

The capstone requirements and decisions are recorded in [CLAUDE.md](../CLAUDE.md) and [SPENDIFY_BUILD_PLAN.md](../SPENDIFY_BUILD_PLAN.md). These documents explain the fixed stack and Android-only scope. Historical measurements remain in [TEST_RESULTS.md](TEST_RESULTS.md); record the commands and actual results for new changes rather than presenting previous results as a new test run.

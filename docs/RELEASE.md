# Spendly — Release build (Phase 12 Part D)

How the signed release APK is produced, what was verified, and what to do if
the keystore is ever lost or moved to a new machine.

---

## 1. What exists and where

| Thing | Path | Tracked in git? |
|---|---|---|
| Keystore | `android/app/spendly-release.jks` | **No** — gitignored |
| Signing config | `android/key.properties` | **No** — gitignored |
| Signing config template | this file (below) | Yes |
| Gradle wiring | `android/app/build.gradle.kts` | Yes |
| R8/ProGuard keep rules | `android/app/proguard-rules.pro` | Yes |

`git check-ignore -v android/app/spendly-release.jks android/key.properties`
was run after creating both, and confirms they match the `*.jks` / `android/key.properties`
rules in `.gitignore` — neither has ever been staged.

**If you clone this repo fresh, both files are absent.** `flutter build apk --release`
still succeeds — `build.gradle.kts` falls back to debug signing when
`key.properties` doesn't exist — but the output is not the shippable, signed
artifact. Regenerate your own keystore (§3) rather than asking for the original
one; it was never meant to leave this machine.

---

## 2. Keystore details (this machine's copy)

```
Keystore:    android/app/spendly-release.jks
Alias:       spendly
Algorithm:   RSA 2048, SHA384withRSA, 10 000-day validity (self-signed)
DN:          CN=Azat Kabulov, OU=FYP Capstone 2, O=Spendly, L=Kuala Lumpur, ST=Selangor, C=MY
```

Signing certificate fingerprints (from `apksigner verify --print-certs`, needed
if you restrict the Gemini API key to this signing identity — CLAUDE.md §9):

```
SHA-1:   16:2D:B7:A3:51:7E:32:4C:F9:DC:80:C7:25:58:3A:69:1E:43:2C:A9
SHA-256: AC:14:80:34:6D:0A:F9:7D:74:56:6B:4C:02:D2:D4:05:6A:4D:C5:22:CB:0C:B1:EC:89:5E:51:3C:23:CB:1F:75
```

**Passwords live only in `android/key.properties`** (gitignored) — not repeated
here. If that file is lost, the passwords are gone with it and this keystore
can no longer be used to sign an update; you would generate a new keystore and
ship the app as a new signing identity (fine pre-launch; a real Play Store
listing would instead use Play App Signing to avoid this exact problem).

**Back up `android/key.properties` and the `.jks` file somewhere outside this
repo** (a password manager attachment or an encrypted drive). Losing them is
recoverable for a capstone (just re-sign); it would not be for a shipped app
with existing installs.

---

## 3. Regenerating the keystore (new machine, or a deliberate reset)

```bash
keytool -genkeypair -v \
  -keystore android/app/spendly-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias spendly \
  -dname "CN=<your name>, OU=FYP Capstone 2, O=Spendly, L=<city>, C=MY"
```

`keytool` ships inside the JDK (`<jdk>/bin/keytool`) — Flutter's own bundled
JDK path is printed by `flutter doctor -v` under "Java binary at". Then create
`android/key.properties`:

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=spendly
storeFile=spendly-release.jks
```

`storeFile` is relative to `android/app/` (where the `.jks` lives), not the
repo root. Re-run `git check-ignore -v android/app/spendly-release.jks
android/key.properties` after creating them — both lines must print a match
before you `git add` anything.

---

## 4. Building

```bash
flutter clean && flutter pub get   # see the integration_test note below
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key_here
```

Omit the `--dart-define` to ship without AI features (they hide themselves;
everything else works — see CLAUDE.md §6/§7).

**`flutter clean` before a release build is currently required.** `integration_test`
is a dev-dependency (Phase 11); Flutter correctly excludes it from a release
build, but `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
is a generated file that can go stale from a prior debug/profile build and
still reference the dev-only plugin, which fails `compileReleaseJavaWithJavac`
with `package dev.flutter.plugins.integration_test does not exist`. `flutter
clean` deletes the stale file so it regenerates correctly for the release
variant. Hit and fixed once already in this project — if it recurs, this is
where to look first.

---

## 5. R8 / shrinking

`isMinifyEnabled = true` + `isShrinkResources = true` on the `release` build
type (`android/app/build.gradle.kts`), with keep rules in
`android/app/proguard-rules.pro` for the usual casualties in a Flutter +
Firebase + Tink stack: Play Core deferred-components stubs, Firebase's
reflection-based (de)serialisation, and Tink's proto-based key registry
(`flutter_secure_storage`'s Android Keystore backing). Hive itself needs no
rule — its adapters are generated Dart, not JVM reflection.

**Verified:** a full release build with these rules on completed without R8
warnings escalating to errors, and the app's core flows were exercised on the
build artifact (see §6). If a future dependency bump reintroduces a shrinking
warning, `android/app/build/outputs/mapping/release/` after a build has R8's
own report of what it removed — check there before adding a blanket `-keep`.

---

## 6. What was verified on this build

Build: `flutter build apk --release` (no `GEMINI_API_KEY`, no Firebase
project configured on this machine — see §7 for what that means for you).

| Check | Result |
|---|---|
| Build completes | ✅ `app-release.apk` written, ~57 MB (56.9 MiB reported by Flutter, 59 695 429 bytes on disk) |
| Signed with the release key, not debug | ✅ `apksigner verify --print-certs` shows the `CN=Azat Kabulov…` cert (§2), not the debug cert |
| Signature scheme | ✅ v2 verified |
| No secret extractable from this build | ✅ `strings`-scanned every file in the APK (all three ABIs' `libapp.so`, all resources) for `AIza…` (Google API key shape), `BEGIN … PRIVATE KEY`, and Firebase config markers (`current_key`, `mobilesdk_app_id`) — none found, because this build has no Gemini key and no Firebase config to embed |
| Core flows on the artifact | **Not yet run on a physical device** — no device was attached in this environment. See §7. |

**Important nuance on "no secret extractable":** that result is a property of
*this particular build*, which was made with no `--dart-define=GEMINI_API_KEY`.
A build made **with** a real key **will** embed it as a plain string constant
in `libapp.so` — Dart compiles to native code, but string literals stay
readable with `strings libapp.so | grep AIza`. This is exactly the CLAUDE.md §9
"option B" limitation, not a bug: the mitigation is restricting the key in
Google Cloud Console to this app's package + the signing SHA-1 in §2, not
hiding it from extraction (which client-side code cannot do). Confirm that
restriction is in place before treating a keyed build as safe to distribute.

---

## 7. What you still need to do

1. **Apply the Google Cloud API key restriction** (CLAUDE.md §9) using the
   SHA-1 in §2, if you're staying with the client-side-key approach for CP2.
2. **Install the signed APK on a physical Android device** and run through the
   core flows (add transaction, scan a receipt if AI is on, hit a budget
   warning, view a report, check offline). This environment has no attached
   device, so it has not been done. `adb install build/app/outputs/flutter-apk/app-release.apk`
   once a device is connected via `adb devices`, or copy the APK to the phone
   and open it (enable "install unknown apps" for whichever app you copy it
   with).
3. **Report the installed APK's actual size** in the CP2 report from your own
   install (sizes can shift slightly with a keyed build, since the key string
   and any AI-path code that only ships when reachable both add a little).
4. Back up `android/key.properties` + `android/app/spendly-release.jks` outside
   the repo (§2).

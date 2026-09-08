# Firebase setup (Phase 5)

Phase 5 adds Firebase Authentication. The code is written and tested, but it
needs a real Firebase project to actually sign anyone in. Until then the app
still builds and runs — it just shows "Sign-in is not available in this build
yet" on the sign-in screen.

`flutter analyze` and `flutter test` pass **without** any of this, because
`lib/firebase_options.dart` ships as a committed-locally placeholder (it is
gitignored, like `google-services.json`).

## One-time setup (~10 min)

### 1. Create the project

1. Go to <https://console.firebase.google.com> and sign in with any Google
   account.
2. **Add project** → name it `spendly` (or anything) → **disable** Google
   Analytics (not used) → **Create project**.

### 2. Enable Email/Password sign-in

In the project: **Build → Authentication → Get started → Sign-in method →
Email/Password → Enable → Save**.

(If you skip this, the app shows: "Email/password sign-in is not enabled for
this project…" — that is the `operation-not-allowed` case, handled.)

### 3. Register the Android app + generate config

Install the CLIs once:

```bash
npm install -g firebase-tools          # the Firebase CLI
firebase login                         # opens a browser
dart pub global activate flutterfire_cli
```

Then, from the project root:

```bash
flutterfire configure --project=<your-project-id> --platforms=android
```

Pick the Android app when prompted; the package name is
`com.azatkabulov.spendly`. This:

- regenerates `lib/firebase_options.dart` with real values (overwrites the
  placeholder — the app auto-switches from "unavailable" to live auth);
- writes `android/app/google-services.json`;
- adds the `com.google.gms.google-services` Gradle plugin.

Both generated files are gitignored on purpose — keep them local.

### 4. Verify

```bash
git check-ignore -v android/app/google-services.json   # must print a match
git status                                             # no secrets staged
flutter test && flutter analyze                        # still green
flutter run                                            # sign-up should work now
```

## The critical test (Phase 5 acceptance)

1. Register a new account **online**.
2. Add 2–3 transactions.
3. Fully close the app (swipe away).
4. Turn **on** airplane mode.
5. Reopen.

→ It must go **straight to the home screen** with all data visible — no login
prompt, no spinner, no wait on Firebase. That is the whole point of the phase.

Also check:

- Sign out (Settings → Sign out), sign back in → data still there, not
  duplicated.
- Airplane mode on **with no prior login** → reaches the sign-in screen with a
  clear offline message, does not hang.

## How the offline guarantee is implemented

- On login, the Firebase UID + email are written to `flutter_secure_storage`
  (`AuthSessionStore`). No password is ever stored.
- `main()` reads that persisted session **directly from secure storage** — not
  from `FirebaseAuth` — and routes on it. `authStateChanges()` is never used
  (it can hang or emit null offline).
- `Firebase.initializeApp` is time-boxed (8 s) and never fatal: a failure still
  reaches the sign-in screen with a message.
- `AuthGate` switches on local `Session` state only.

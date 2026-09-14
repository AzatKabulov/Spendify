# Firebase setup (Phases 5 & 6)

Phase 5 adds Firebase Authentication; Phase 6 adds Firestore as a per-user
backup/restore target (**not** the source of truth — see CLAUDE.md §3). Both
are fully coded and tested, but need a real Firebase project to actually do
anything. Until then the app still builds and runs — sign-in just shows
"Sign-in is not available in this build yet", and Settings' backup section
shows "Backup not set up".

`flutter analyze` and `flutter test` pass **without** any of this, because
`lib/firebase_options.dart` ships as a committed-locally placeholder (it is
gitignored, like `google-services.json`).

## One-time setup (~15 min)

### 1. Create the project

1. Go to <https://console.firebase.google.com> and sign in with any Google
   account.
2. **Add project** → name it `spendify` (or anything) → **disable** Google
   Analytics (not used) → **Create project**.

You're on the free **Spark** plan by default — that's all Auth + Firestore
need. Blaze (paid) is only needed if you later add a Cloud Function proxy for
the Gemini key (CLAUDE.md §9, option A) — unrelated to this setup.

### 2. Enable Email/Password sign-in

In the project: **Build → Authentication → Get started → Sign-in method →
Email/Password → Enable → Save**.

(If you skip this, the app shows: "Email/password sign-in is not enabled for
this project…" — that is the `operation-not-allowed` case, handled.)

### 3. Create the Firestore database

**Build → Firestore Database → Create database.**

- Pick any region (e.g. `asia-southeast1` for Malaysia) — this can't be
  changed later, but only affects latency, not correctness.
- Start in **Production mode**, not test mode — the rules in step 4 replace
  whatever default Firestore would otherwise apply.
- **Create.**

### 4. Publish the security rules

`firestore.rules` (repo root, tracked in git — no secrets in it) restricts
every read/write to `users/{the signed-in uid}/...` and denies hard deletes
(tombstones only — see `sync_manager.dart`).

1. In Firestore: the **Rules** tab.
2. Select all the existing text in the editor, delete it.
3. Paste in the full contents of `firestore.rules`.
4. **Publish.**

Don't skip this — until published, the database is either wide open or fully
locked (whichever the console defaulted to), and the cross-user protection the
app relies on isn't live yet either way.

### 5. Register the Android app + generate config

Install the CLIs once:

```bash
npm install -g firebase-tools          # the Firebase CLI
firebase login                         # opens a browser — same Google account as step 1
dart pub global activate flutterfire_cli
```

If `flutterfire --version` isn't found afterward, its executable landed in
Dart's global pub-cache bin, which may not be on your PATH yet:
`%LOCALAPPDATA%\Pub\Cache\bin` on Windows (add it, then reopen your terminal).

Then, from the project root:

```bash
flutterfire configure --project=<your-project-id> --platforms=android
```

`<your-project-id>` is the id shown top-left in the console under the project
name (e.g. `spendify-a1b2c`) — not the display name you typed in step 1. Pick
**register a new Android app** when prompted; the package name is
`com.azatkabulov.spendly`. This:

- regenerates `lib/firebase_options.dart` with real values (overwrites the
  placeholder — the app auto-switches from "unavailable" to live auth/sync);
- writes `android/app/google-services.json`;
- adds the `com.google.gms.google-services` Gradle plugin.

Both generated files are gitignored on purpose — keep them local.

### 6. Verify

```bash
git check-ignore -v android/app/google-services.json lib/firebase_options.dart
git status                                             # no secrets staged
flutter test && flutter analyze                        # still green
flutter run                                            # sign-up should work now
```

`check-ignore` **must print a match for both files** — if either prints
nothing, stop before running any other git command and double-check, because
that means a real secret is about to be trackable.

## The critical tests

### Phase 5 — offline session

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

### Phase 6 — sync, once the above passes

- **Offline queue**: add/edit while offline (`pending` shown in Settings) →
  reconnect → flips to `synced`.
- **Tombstone**: delete a transaction, let it sync, use Settings → "Delete all
  local data", sign back in → the deleted transaction must **not** reappear.
- **Restore**: with ~50 synced transactions, uninstall + reinstall (or "Delete
  all local data" then sign back in), → everything comes back, reports/budgets
  show correct numbers.
- **Kill mid-sync**: force-close the app while syncing → nothing lost or
  duplicated on relaunch.
- **Security rules — deliberately try to break in**: sign in as user A, note a
  document id from the Firestore console under `users/{A's uid}/transactions`,
  then from a second account (user B) attempt to read or write
  `users/{A's uid}/transactions/{that id}` (easiest via the Firebase console's
  Rules Playground, or a quick authenticated `curl`/script) — it must be
  **rejected**. Don't assume the rules work just because they're written
  correctly; this is the one check that verifies the *deployed* rules, not the
  local file.

## How the offline guarantee is implemented

- On login, the Firebase UID + email are written to `flutter_secure_storage`
  (`AuthSessionStore`). No password is ever stored.
- `main()` reads that persisted session **directly from secure storage** — not
  from `FirebaseAuth` — and routes on it. `authStateChanges()` is never used
  (it can hang or emit null offline).
- `Firebase.initializeApp` is time-boxed (8 s) and never fatal: a failure still
  reaches the sign-in screen with a message.
- `AuthGate` switches on local `Session` state only.
- `SyncManager` (Phase 6) only ever reads local `pending` rows and writes
  results back — it never sits on the path between the UI and a save.
  `PeriodAggregate` and `AdviceRecord` are deliberately not synced (derived /
  regenerable locally) — see CLAUDE.md §9.

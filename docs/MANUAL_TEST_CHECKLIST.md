# Spendly — Manual test checklist

Everything automatable has been run (`flutter analyze`, the full test suite,
the algorithmic + on-device performance tests, the offline reliability
matrix — see `docs/TEST_RESULTS.md` for the numbers). This document is what's
left: things that need a live Firebase project, a live Gemini key, a physical
device, or another human — none of which can be scripted from here.

Tick each box as you go. Where something fails, note what happened underneath
it rather than just leaving it unchecked — a documented near-miss is worth
more than a silent gap (per `CLAUDE.md`'s own testing philosophy).

---

## Phase 5 — Firebase Authentication (live)

Prerequisite: Firebase project created, Email/Password enabled, `flutterfire
configure` run (all done as of 2026-09-13).

- [ ] Fresh install (or Settings → "Delete all local data" first). Sign-up
      screen shows normally, no "not available" message.
- [ ] Register a new account with a real-looking email + password.
- [ ] Lands on home screen with no data (fresh account).
- [ ] Add 2–3 transactions.
- [ ] Fully close the app (swipe away from recents, not just backgrounded).
- [ ] Turn on **airplane mode**.
- [ ] Reopen the app → **must land straight on home** with your transactions
      still there. No login prompt, no spinner, no delay waiting on Firebase.
- [ ] Turn airplane mode back off.
- [ ] Settings → Sign out → confirm dialog → back at sign-in.
- [ ] Sign back in with the same account → same data, **not duplicated**.
- [ ] Turn on airplane mode **before** opening the app at all (no prior
      session on this install) → reaches sign-in with a clear offline
      message, doesn't hang.

**If anything fails here**, check the `flutter run` terminal for a line
starting `AUTH form: unexpected` or `STARTUP:` — that has the real error code.

---

## Phase 6 — Sync Manager (live, do after Phase 5 passes)

Prerequisite: Firestore database created, `firestore.rules` published (done
2026-09-13).

- [ ] **Offline queue**: turn on airplane mode, add a transaction. Settings →
      Backup & sync shows it as pending. Turn airplane mode off → within ~15s
      (or tap "Sync now") it flips to synced.
- [ ] **Tombstone**: delete a transaction, wait for sync, then Settings →
      "Delete all local data" → sign back in with the same account → the
      deleted transaction must **not** reappear.
- [ ] **Restore**: with a handful of synced transactions, "Delete all local
      data" → sign back in → everything comes back, reports/budgets show
      correct numbers (not doubled, not missing).
- [ ] **Kill mid-sync**: add several transactions at once while online, then
      immediately force-close the app before the sync icon settles. Reopen →
      nothing lost, nothing duplicated.
- [ ] **Cross-user rules probe** (lower priority — proves the *deployed*
      rules, not just the local file): create a second test account. Sign in
      as it, note that you cannot see the first account's data anywhere in
      the app (expected — the app only ever queries its own uid's subtree).
      For a stronger check: in the Firebase console, open Firestore data,
      copy a document path under the first account's `users/{uid}/...`, then
      use the console's **Rules Playground** (Firestore → Rules → the
      "Rules playground" tool) simulating a **get** request as the *second*
      user's uid against that path → must show **Denied**.

---

## Phase 7 — Receipt Scanner (live Gemini)

Prerequisite: a Gemini key in `secrets.json`, run with
`flutter run --dart-define-from-file=secrets.json`.

- [ ] First launch with the key present shows the **AI consent screen**
      before home. Read it, tap "Turn on AI".
- [ ] Scan/camera FAB appears above Add on the home screen.
- [ ] Scan **~10 real receipts**, varied: printed, a phone-screen photo,
      one crumpled, one dimly lit. For each, record whether amount / date /
      merchant came back usable:

  | # | Receipt type | Amount ok? | Date ok? | Merchant ok? | Notes |
  |---|---|---|---|---|---|
  | 1 | printed | | | | |
  | 2 | printed | | | | |
  | 3 | phone screen | | | | |
  | 4 | phone screen | | | | |
  | 5 | crumpled | | | | |
  | 6 | crumpled | | | | |
  | 7 | dim lighting | | | | |
  | 8 | dim lighting | | | | |
  | 9 | (your choice) | | | | |
  | 10 | (your choice) | | | | |

  **This honest hit-rate is real CP2 evidence** — a lower number with
  analysis is worth more than an unverified "it works great" claim.

- [ ] Every extracted field is shown, editable, before saving (should already
      be true by construction — confirm visually).
- [ ] Scan a receipt, then back out **without** tapping Save → nothing is
      added to the transaction list.
- [ ] Photograph a blank wall → falls back to the manual entry form, no
      crash.
- [ ] Turn on airplane mode, try to scan → clear "needs an internet
      connection" message + "Enter manually" option, no crash, no hang.

---

## Phase 9 — Advice Generator (live Gemini)

- [ ] With real spending logged (ideally 10+ transactions across a few
      categories), open **Insights**. Advice should reference your *actual*
      categories and rounded amounts (e.g. "your spending on Food"), not
      generic tips.
- [ ] Open Insights again without changing any data → should **not** re-call
      Gemini (served from cache) — the "Last updated" timestamp stays the
      same as the first open.
- [ ] Add a new transaction, then open Insights → this time it should
      regenerate (data changed → hash changed).
- [ ] Turn on airplane mode, open Insights → shows the last cached advice
      with its timestamp, plus a quiet offline note — never a blank error
      screen, never an endless spinner.
- [ ] Settings → "What's sent to Gemini" → confirm the JSON shown has no
      merchant names, no notes, no individual transaction amounts, no email,
      no uid — only rounded aggregates.

---

## Phase 10 — Privacy & security (manual spot-checks)

Most of this phase is already automated (`settings_privacy_test.dart`,
`ai_consent_test.dart`, `local_data_wiper_test.dart`). What's left needs
eyes on the actual output:

- [ ] Settings → "Export my data" → Save file → open the resulting JSON in a
      text editor → confirm it's complete and readable (not garbled), and
      that a receipt image is **not** embedded anywhere in it.
- [ ] Settings → AI toggle **off** → Scan FAB and Insights menu entry
      disappear immediately; rest of the app still works.
- [ ] Toggle AI back **on** → both reappear without needing to restart the
      app.

---

## Phase 11 — Usability test (real people — the one that's actually graded)

Full protocol, results sheet and SUS questionnaire: `docs/USABILITY_TEST_PROTOCOL.md`.

- [ ] Recruit 3–5 people who have never seen Spendly.
- [ ] Fresh install on the device they'll use, no instructions given.
- [ ] One task per person: *"You just spent RM 12.50 on lunch. Record that in
      the app."* Time from app-open to a saved transaction.
- [ ] Note hesitations / wrong taps / think-aloud comments per participant.
- [ ] Immediately after, have them fill in the 10-item SUS questionnaire.
- [ ] Fill the results into `docs/TEST_RESULTS.md §5` (median time, pass rate
      against 60s, SUS score, common friction points).

## Phase 11 (cont.) — Physical-device performance

- [ ] Install a debug or profile build on a real mid-range Android phone.
- [ ] `flutter test integration_test/performance_test.dart -d <device-id>`
      (find the id with `flutter devices` once it's plugged in with USB
      debugging on).
- [ ] Update `docs/TEST_RESULTS.md §3` with the real numbers + the device
      model/specs, replacing the emulator-only caveat.

---

## Phase 12 — Release build + demo (physical device)

- [ ] Rebuild the release APK now that Firebase + Gemini are both configured
      (the one already built predates both):
      `flutter clean && flutter build apk --release --dart-define-from-file=secrets.json`
- [ ] Install it on a real device: `adb install build/app/outputs/flutter-apk/app-release.apk`
      (or copy the file to the phone and open it).
- [ ] Run the core flows on that installed release build: add a transaction,
      hit a budget warning, view a report, scan a receipt, toggle airplane
      mode.
- [ ] Confirm the app icon and splash screen show correctly (not the default
      Flutter icon).
- [ ] Rehearse `docs/DEMO_SCRIPT.md` end to end, out loud, including the
      airplane-mode segment, at least once before presenting it for real.
- [ ] Load the demo dataset for the actual presentation:
      `flutter run --dart-define=DEMO_SEED=true --dart-define-from-file=secrets.json`

---

## Housekeeping (do once, anytime)

- [ ] Back up `android/key.properties` and `android/app/spendly-release.jks`
      outside this repo (password manager attachment, encrypted drive).
      Both are gitignored — losing them means losing the ability to
      re-sign an update under the same identity.
- [ ] Decide the Gemini key placement (client-side vs. Cloud Function proxy)
      with your supervisor and record the outcome in `CLAUDE.md §9`
      (currently marked PROVISIONAL).
- [ ] If staying client-side: apply the Google Cloud API key restriction
      (Android package `com.azatkabulov.spendly` + signing SHA-1
      `16:2D:B7:A3:51:7E:32:4C:F9:DC:80:C7:25:58:3A:69:1E:43:2C:A9`, API
      restricted to Generative Language API only).

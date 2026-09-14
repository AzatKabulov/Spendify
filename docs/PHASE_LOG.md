# Spendify — Phase log

What shipped in each phase of `SPENDIFY_BUILD_PLAN.md`, and the commit it
landed in. Design decisions that deviated from the original brief are flagged
— full rationale for each lives in `CLAUDE.md §9`.

| Phase | What shipped | Commit |
|---|---|---|
| 0 | Android-only Flutter scaffold, toolchain pinned (JDK 21, minSdk 24) | `e13dbbf` |
| 1 | Domain entities, AES-encrypted Hive storage, repositories, Riverpod wiring | `32858bb` |
| 2 | Transaction Manager + manual entry UI, fully offline | `48e011c` |
| 3 | Categories + Budget Manager (`BudgetEvaluator`, pure) | — |
| 4 | Weekly/monthly/yearly reports from a cached `PeriodAggregate` layer | — |
| 4.1 | Daily aggregates, budget/aggregate reconciliation tests, AppBar regression guard, `Result<T>` question closed in favour of typed exceptions | `443f379` |
| 5 | Firebase Authentication, offline-session routing (never a `FirebaseAuth` stream) | `c41eb53` |
| 6 | Hive ↔ Firestore backup/restore (Sync Manager), last-write-wins, tombstones | `4138b03` |
| 7 | Receipt Scanner Module (Gemini vision), confirm-before-save | `30c9a9e` |
| 8 | Gamification Engine — XP, coins, levels, badges, streaks | `e38a578` |
| 9 | Advice Generator — aggregated summary → Gemini → cached advice | `e7ce2d1` |
| 10 | Security, privacy and ethics surfaces (AI consent, data export, delete-all, hardening) | `ee8eb4b` |
| 11 | NFR test pass — performance, offline reliability, coverage, usability materials | `574fdcb` |
| 12 | Polish + release build — theming, empty/loading/error states, accessibility, signed APK, demo dataset, docs | *(this commit)* |

---

## Deviations from the original brief, in one place

Each of these is explained in full where it was decided — this is an index,
not the rationale.

- **`Result<T>` vs typed exceptions** — closed at Phase 4.1 in favour of
  exceptions. `CLAUDE.md §8`.
- **`GamificationState` gained 5 fields** beyond the original spec
  (`transactionsLogged`, `budgetsCreated`, `budgetPeriodsWithinLimit`,
  `scannedTransactionsLogged`, `recentEventIds`) so the pure engine can check
  every badge and dedupe events without reaching into a repository.
  `CLAUDE.md §4`.
- **`AdviceRecord.adviceItems`** became `List<AdviceItem>` (`{title, body}`)
  instead of `List<String>` — no Hive schema change, a mapper bridges it.
  `CLAUDE.md §4`.
- **`AdviceRecord` and `PeriodAggregate` are not synced to Firestore** —
  both are locally derived/regenerable, so a sync would fight the local
  rebuild rather than help it. `CLAUDE.md §9` / phase6-sync memory.
- **Receipt image compression targets the short edge**, not the long edge as
  the original spec said — receipts are vertical and text-dense, so more
  vertical resolution reads better.
- **The Gemini API key ships client-side** (CLAUDE.md §9 "option B"),
  provisionally, because the Cloud Function proxy (option A) needs a Blaze
  plan that wasn't set up during the build. Documented as a known limitation;
  mitigated with Google Cloud key restrictions (`docs/RELEASE.md §2/§7`).
- **AI consent is device-level, not per-user, not synced** — the simplest
  defensible choice for a capstone; a stricter design would key it per-uid.
  `CLAUDE.md §9`.
- **`flutter clean` is required before a release build** on this toolchain
  version, because a stale `GeneratedPluginRegistrant.java` from a prior
  debug build can still reference the `integration_test` dev-dependency.
  `docs/RELEASE.md §4`.

---

## What is deliberately future work, not a gap

- **Dark mode** — the app is intentionally locked to a single light theme
  (`AppTheme.light()`, no `darkTheme` passed to `MaterialApp`) rather than
  building a half-finished second theme. Noted in `README.md` / `CLAUDE.md`.
- **Cloud Function key proxy (option A)** — see above; the client behind
  `ReceiptScannerRepository`/`AdviceGeneratorRepository` already isolates the
  change to one endpoint constant if this is picked up later.
- **Multi-device realtime merge** — Phase 6 sync is single-device
  backup/restore by design (report §1.4.3), not a CRDT-style live merge.

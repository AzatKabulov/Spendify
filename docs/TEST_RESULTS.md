# Spendly — Test Results (Phase 11)

Evidence pack for CP2 §3.1 (testing stage) and §3.2.2 (non-functional
requirements). Every requirement in `CLAUDE.md §6` has a measured result below,
pass or fail. Where a target is missed, the number and the analysis are both
recorded — an unverified "it's fast" claim is worth less than a documented
near-miss.

_Generated 2026-09-11. Re-run any section with the commands shown._

---

## 1. Summary — NFRs against their targets

| # | NFR (`CLAUDE.md §6`) | Target | Measured result | Verdict |
|---|---|---|---|---|
| 1 | **Performance** — core actions | < 2 s on a mid-range Android device | All 6 core actions: median 177–823 ms on the test emulator (debug). Worst single sample 2 022 ms (a first-run cold start). Algorithmic cost of every screen's data layer: < 5 ms with 5 000 transactions. | **PASS** (median); one cold-start outlier grazes the bar — see §3 |
| 2 | **Reliability** — offline | All core functions work with zero connectivity, except the two AI features | 14/14 capabilities pass with connectivity forced off; receipt scanning, advice regeneration and sync all degrade with a message, no crash. | **PASS** |
| 3 | **Security** — encryption / HTTPS / no plaintext creds | Local data encrypted at rest; HTTPS only; no plaintext credentials (OWASP MASVS baseline) | Full audit in Phase 10 (`docs/` / commit `ee8eb4b`): all 7 Hive boxes AES-encrypted, key in Android Keystore only; `usesCleartextTraffic=false` + network-security-config; no password persisted; no key in tracked source or the keyless APK. | **PASS** (1 documented limitation: a *keyed* release APK embeds the Gemini key — `CLAUDE.md §9`) |
| 4 | **Usability** — first transaction | First-time user saves their first transaction in < 60 s, no instructions | **Not yet measured** — needs 3–5 real participants. Protocol, results sheet and SUS questionnaire are ready in `docs/USABILITY_TEST_PROTOCOL.md`. | **PENDING** (materials ready) |
| 5 | **Scalability** — multi-year history | Stays responsive with multi-year history | 5 000 transactions / 3 years / 15 categories seeded. Report, budget and balance computations are O(aggregates) not O(transactions): 0.2–5 ms each. Aggregate cache is ~8 300 rows and loads from encrypted Hive in ~3 ms. | **PASS** |
| 6 | **Maintainability** — replaceable layers | AI, storage and gamification each behind an interface | `GeminiReceiptClient`/`GeminiAdviceClient` behind `ReceiptScannerRepository`/`AdviceGeneratorRepository`; `UnavailableReceiptScanner`/`UnavailableAdviceGenerator` are drop-in replacements already used when AI is off. Storage behind `*Repository` interfaces with in-memory fakes used by 40+ widget tests. `GamificationEngine` is pure, no Hive/Firebase/Flutter imports. `domain/` has zero `data/` imports (enforced by review). | **PASS** |

---

## 2. Test coverage

```
flutter test --coverage
```

| Metric | Value |
|---|---|
| Test files | 51 (`test/`) + 1 (`integration_test/`) |
| Test cases | 379 unit + widget, all passing |
| Line coverage (overall) | **74.0 %** (3 850 / 5 206) |
| `domain/services` (the pure logic the report commits to unit-testing) | **93.7 %** (613 / 654) |
| `presentation/widgets` | 89.9 % |
| `presentation/screens` | 78.4 % |
| `presentation/providers` | 70.3 % |
| `data/repositories` | 73.3 % |

### Critical paths covered

| Path | Covered by |
|---|---|
| `BudgetEvaluator` (thresholds, period windows, scan-vs-aggregate consistency) | `budget_evaluator_test.dart`, `budget_reconciliation_test.dart` (300 randomised cases) |
| `AggregationService` / `AggregationMaintenance` (incremental == full rebuild) | `aggregation_service_test.dart`, `aggregation_maintenance_test.dart` ("~60 random ops == rebuildAll") |
| `GamificationEngine` (awards, streak break, backdating, idempotency, reversal) | `gamification_engine_test.dart` (26), `gamification_rules_test.dart`, `gamification_reconciler_test.dart` |
| `AdviceSummaryBuilder` + data-minimisation payload | `advice_summary_builder_test.dart` (asserts no ids / merchants / notes / uid in the payload) |
| Sync conflict resolution (LWW, tombstones, single-flight, interruption) | `sync_manager_test.dart` (13), `sync_policy_test.dart` |
| Gemini response parsing (fences, prose, partial, truncated, malformed) | `receipt_json_parser_test.dart` (12), `advice_json_parser_test.dart` (13), `gemini_client_test.dart`, `gemini_advice_client_test.dart` |
| Money utilities (`>2 dp` rejected, sen ↔ display) | `money_test.dart` (100 %) |
| Encryption at rest (value not readable in the raw `.hive` file) | `encryption_at_rest_test.dart` |
| userId migration (idempotent, resumable, refuses a different uid) | `user_id_migration_test.dart` (6) |
| Consent gating (no Gemini client constructed when AI off) | `ai_consent_test.dart` (11) |
| Delete-all-data (every box cleared, app re-reads a clean state) | `local_data_wiper_test.dart` |
| Data export (valid, complete, parseable) | `data_exporter_test.dart` (3) |

### Not covered, and why

| Area | Reason |
|---|---|
| `firebase_auth_repository.dart` (0 %) | Wraps the Firebase Auth SDK; the pure error-code → typed-exception mapper *is* fully tested (`firebase_auth_error_mapper_test.dart`, 14 cases). |
| `firestore_sync_gateway.dart` (32 %) | The `cloud_firestore` transport. `Timestamp ↔ DateTime` boundary + `classifyFirestoreError` are tested; the wire calls need a live Firestore (deferred with the Phase 6 device checks). |
| `receipt_image_processor.dart` (6 %) | `image_picker` + `flutter_image_compress` are platform plugins. The temp-file-delete-in-`finally` contract is verified by reading; a device check is in the offline matrix. |
| `.g.dart` files | Generated Hive adapters — exercised indirectly by every repository test; not meaningful to unit-test directly. |
| `firebase_options.dart` | A gitignored placeholder stub. |

---

## 3. Performance measurement (NFR 1)

### 3.1 Test environment

| | |
|---|---|
| Device | Android emulator `sdk_gphone64_x86_64` (x86-64), Android 16 / API 36, 4 vCPU, ~2.5 GB RAM, software GPU |
| Build mode | **debug** (no AOT, no tree-shaking, slower rendering) — numbers are therefore **conservative**; a real device in release is faster |
| Dataset | 5 000 transactions over 3 years, 15 categories, seeded deterministically (`Random(42)`); aggregate cache rebuilt (~8 300 rows) |
| Method | each action run 5×; median and worst single sample reported |
| Not measured on | a physical mid-range phone — **the one gap**; see §3.4 |

### 3.2 On-device (widget build + settle, includes Keystore fetch + AES decryption)

```
flutter test integration_test/performance_test.dart -d <device>
```

| Core action | Budget | Median | Worst | Verdict |
|---|---:|---:|---:|:--:|
| Cold start → home rendered | 2 000 ms | **520 ms** | 2 022 ms | PASS |
| Open the add-transaction form | 2 000 ms | **232 ms** | 852 ms | PASS |
| Save a transaction (tap → back on list) | 2 000 ms | **823 ms** | 1 074 ms | PASS |
| Open monthly report | 2 000 ms | **505 ms** | 758 ms | PASS |
| Open budget list (16 statuses evaluated) | 2 000 ms | **177 ms** | 239 ms | PASS |
| Open rewards / stats screen | 2 000 ms | **368 ms** | 500 ms | PASS |

**Cold-start worst case (2 022 ms)** is a single first-run sample: debug-mode JIT
warm-up plus the ~850 ms Keystore key fetch (`HIVE bootstrap: key=859ms`), which
matches the Phase 2 finding that the Keystore read dominates cold start. Median
520 ms is well inside the bar. On a real device the hardware-backed Keystore is
faster and release-mode AOT removes the JIT warm-up, so this outlier is not
expected to reproduce — but it is recorded here rather than hidden.

### 3.3 Algorithmic cost (Dart VM, the data layer behind each screen)

```
flutter test test/performance/perf_scaling_test.dart
```

| Operation | Budget | Median | Worst | Verdict |
|---|---:|---:|---:|:--:|
| Rebuild **all** aggregates (one-off: first launch / after migration) | 2 000 ms | **108 ms** | 198 ms | PASS |
| Load the PeriodAggregate cache (8 292 rows, encrypted Hive) | 300 ms | **2.6 ms** | 3.0 ms | PASS |
| Home: balance + income/expense split | 50 ms | **0.4 ms** | 1.4 ms | PASS |
| Home: recent-transaction list (load 5 000 + display sort) | 500 ms | **4.2 ms** | 7.8 ms | PASS |
| Open monthly report (figures + category breakdown) | 100 ms | **0.2 ms** | 0.7 ms | PASS |
| Report "spend over time" per-day bars (monthly) | 100 ms | **1.3 ms** | 2.3 ms | PASS |
| Open yearly report (12 monthly bars) | 100 ms | **0.2 ms** | 0.5 ms | PASS |
| Open budget list (16 budget statuses from the cache) | 100 ms | **3.2 ms** | 5.5 ms | PASS |
| Save a transaction (persist + 8-aggregate incremental update) | 300 ms | **0.7 ms** | 3.4 ms | PASS |
| _reference:_ balance by full transaction scan (pre-Phase-4) | 2 000 ms | 0.9 ms | 1.2 ms | — |

This is the concrete evidence for **NFR 5 (scalability)** and the **§6
performance commitment** that "reports are generated from locally cached
aggregates, not by recalculating over the full transaction history": every
report/budget/balance operation is O(aggregate rows), independent of how many
transactions exist. The reference row shows a full scan is also fast *in
memory* — the real Phase-4 win is that opening a report never has to **load and
decrypt** 5 000 rows from Hive, only ~8 300 small aggregate rows once.

### 3.4 Known gap

The numbers above are from an x86-64 emulator in debug mode. Per the phase
brief this should also be run on **a physical mid-range Android phone in
release/profile mode** and the device + specs stated. That run is a manual
step (see `docs/USABILITY_TEST_PROTOCOL.md` §4, which also covers this) — the
harness is ready:

```
flutter test integration_test/performance_test.dart -d <physical-device>
```

---

## 4. Offline reliability matrix (NFR 2)

```
flutter test test/offline/offline_reliability_test.dart
```

Connectivity is **forced off** for every row.

| Capability | Result |
|---|---|
| Add transaction | PASS — works offline |
| Edit transaction | PASS — works offline |
| Delete transaction | PASS — works offline |
| Create / edit / delete category | PASS — works offline |
| Create budget | PASS — works offline |
| Budget warning (approaching / exceeded) | PASS — evaluated from the local aggregate cache |
| Weekly / monthly / yearly reports | PASS — rendered from the cache |
| Gamification XP / coins / streak | PASS — engine fires offline |
| Stats / rewards screen | PASS — renders offline |
| App relaunch with session intact | PASS — startup routing reads local secure storage only, no Firebase call |
| Cached advice visible + timestamp | PASS — served from cache, **zero API calls** |
| Receipt scanning | **Degrades** — "needs an internet connection" + manual-entry fallback, no crash |
| Advice regeneration (no cache) | **Degrades** — honest "you're offline" message, no spinner, no crash |
| Background / manual sync | **Degrades** — no-op, no crash, local writes are kept and queued |

14 / 14. No core feature depends on connectivity; the two AI features and sync
fail soft with a message. This is the automated evidence for the report's
central offline-first claim.

**Manual confirmation still recommended:** run the same list on a physical
device in real airplane mode, and confirm the airplane-mode demo end to end
(Phase 12 demo script §"offline demonstration").

---

## 5. Usability test (NFR 4) — PENDING

Needs real participants. All materials are in
**`docs/USABILITY_TEST_PROTOCOL.md`**:

- test protocol (fresh install, no instruction, one task: "record that you
  spent RM 12.50 on lunch today")
- a printable per-participant results sheet (timing, hesitations, wrong taps,
  think-aloud notes)
- a 10-item **System Usability Scale (SUS)** questionnaire, so the CP2 score is
  directly comparable to the SUS scores cited in the literature review

Fill in §6 of this document once collected:

| Participant | Time to first saved transaction | < 60 s? | SUS score | Main friction |
|---|---|---|---|---|
| P1 | | | | |
| P2 | | | | |
| P3 | | | | |
| P4 | | | | |
| P5 | | | | |
| **Median** | | | | |

---

## 6. Known limitations and defects (stated plainly)

1. **Gemini API key in a keyed release APK is extractable.** Documented open
   decision (`CLAUDE.md §9`). Mitigation if staying client-side: Google Cloud
   API-key restrictions. Proper fix: a Cloud Function proxy (needs the Blaze
   plan). The keyless build has no key at all.
2. **Firestore sync is not live-verified.** Code + 13 unit tests are done, but
   the 7 device checks (tombstone, restore, cross-user rule probe, mid-sync
   interruption) need a real Firebase project + `flutterfire configure`. Carried
   from Phase 6.
3. **Performance not measured on physical hardware.** Emulator numbers only;
   see §3.4. Expected to be *faster* on release + real device, but unverified.
4. **Usability test not run.** Materials ready; needs participants.
5. **Consent is device-level, not per-user.** If two accounts share one device,
   the second inherits the first's AI choice. Acceptable for a single-user
   capstone; noted in `CLAUDE.md §9`.
6. **Daily aggregate rows grow ~1 per active category per day** (~8 300 for
   3 years). Well within Hive's comfort zone and load is ~3 ms, but a prune
   policy for very old daily rows is noted as future work in
   `aggregation_service.dart`.
7. **`integration_test` re-uses one Hive lifecycle per run.** The suite works
   but cannot cleanly reset Hive between `testWidgets` in the same file (Hive is
   a process-global singleton) — the perf test is deliberately a single test.

---

## 7. How to reproduce everything

```bash
flutter test                                              # 379 tests, unit + widget
flutter test --coverage                                   # + coverage/lcov.info
flutter test test/performance/perf_scaling_test.dart       # algorithmic perf
flutter test test/offline/offline_reliability_test.dart    # offline matrix
flutter test integration_test/performance_test.dart -d <d> # on-device perf
flutter analyze                                            # static analysis, clean
```

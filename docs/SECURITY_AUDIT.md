# Spendly — Security Audit & Remediation (Phase 12)

A full read-only security/architecture audit of the codebase, run against
commit `a5bee9e`, followed by the fixes it led to. Kept as CP2 evidence that a
security review actually happened and was acted on, not just claimed.

**Overall rating at audit time: Good.** No CRITICAL findings. One HIGH
finding — already known and disclosed in `CLAUDE.md §9`, not a surprise
discovery. Two MEDIUM findings, both fixed same-day. A handful of LOW/INFO
items, addressed or consciously deferred with rationale below.

---

## Findings and their outcome

| # | Severity | Finding | Outcome |
|---|---|---|---|
| 1 | HIGH | Gemini API key is extractable from a *keyed* release build (`strings libapp.so`) | **Accepted, disclosed, mitigation pending your action** — CLAUDE.md §9 already named this; the fix is a Google Cloud key restriction, which needs your Google account (§"What still needs you" below). Not something code can fix — client-side keys are inherently extractable. |
| 2 | MEDIUM | `delete()` / `restore()` / `upsertFromRemote()` on `BaseSyncableHiveRepository` didn't re-check record ownership (`userId`) the way every read method does | **Fixed** — `lib/data/repositories/base_syncable_hive_repository.dart`. All four id-based mutation paths now treat a foreign-owned record as if it doesn't exist, via a shared `_ownedOrNull()` helper. 6 new tests in `test/data/repositories/transaction_repository_test.dart` prove a second user's repository instance over the same box can't touch, resurrect, mark-synced, or overwrite another user's record. |
| 3 | MEDIUM | Gemini API key sent as a URL query parameter (`?key=...`) instead of a header | **Fixed** — both `gemini_client.dart` and `gemini_advice_client.dart` now send the key via the `x-goog-api-key` header; the endpoint URL no longer contains it at all. New tests in both `test/data/remote/gemini_*_client_test.dart` assert the key is in the header and never appears anywhere in the request URL. |
| 4 | LOW | No certificate pinning (system CA trust only) | **Not changed** — see rationale below. |
| 5 | LOW | `flutter_secure_storage` pinned to `10.3.1`, not latest `11.x` | **Not changed** — see rationale below. |
| 6 | INFO | `firebase_options.dart`'s `apiKey` field looks like a secret in a naive grep | **No action needed** — confirmed this is Google's public client-config value, not a secret; documented here so it isn't re-flagged by a future, less careful pass. |
| — | P2 (hardening, not a finding) | `domain/`'s "no imports from `data/` or any framework package" rule was only enforced by review discipline | **Added** — `test/architecture/layer_boundary_test.dart` scans every file under `lib/domain/` and fails the build if that invariant is ever violated. Currently 0 violations (confirmed before writing the test). |

---

## Why #4 and #5 were consciously left alone

**Certificate pinning** — the app talks to exactly three Google-operated
HTTPS endpoints (Firebase Auth, Firestore, Gemini). System-CA trust is
standard and defensible for this threat model; pinning is real
defense-in-depth but also a common source of self-inflicted outages (an app
update lags a routine certificate rotation and locks users out). Given the
threat model here — a personal finance app talking only to Google's own
infrastructure — the risk pinning defends against (a compromised or
mis-issued CA) is lower-probability than the risk pinning itself introduces
if done without an update mechanism for the pins. Recorded as future work,
not implemented.

**`flutter_secure_storage` version** — pinned to `10.3.1` since Phase 0 for a
documented, unrelated reason: `11.x` forces `compileSdk 37`, and this
machine's Android SDK only has plain `platforms;android-36` available (`37`
exists only as minor-versioned packages), which breaks the AGP target
lookup. This is a **build-tooling constraint, not a security downgrade** —
no specific vulnerability is known in `10.3.1` that `11.x` fixes. Bumping it
today would trade a known-working build for an unknown one, to fix a
finding with no concrete exploit behind it. Left alone; revisit when the
platform package situation resolves upstream.

---

## What still needs you (not fixable from here)

1. **Apply the Google Cloud API key restriction** (Finding #1's actual
   mitigation): Google Cloud Console → APIs & Services → Credentials → your
   Gemini key → restrict to **Android apps** (package
   `com.azatkabulov.spendly`, SHA-1
   `16:2D:B7:A3:51:7E:32:4C:F9:DC:80:C7:25:58:3A:69:1E:43:2C:A9`) **and**
   API restriction to **Generative Language API** only. This is the one
   action that meaningfully bounds the impact of Finding #1 even if a keyed
   APK's key is ever extracted.
2. **The live cross-user Firestore rules probe** (from the original audit's
   §9 caveat: rules that are *written* correctly and rules that are
   *confirmed* correct once deployed are different claims) — still open,
   tracked in `docs/MANUAL_TEST_CHECKLIST.md`. Ask if you'd like this
   automated against your real project rather than done by hand.

---

## Verification after the fixes

```
flutter analyze                              # clean
flutter test --exclude-tags=perf             # 396 passed, 1 skipped
```

All pre-existing tests still pass; 9 new tests were added specifically to
prove Findings #2 and #3 are actually fixed (not just "code looks different
now"), plus the new architecture-boundary guard.

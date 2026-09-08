# Spendly — Phased Build Plan

Implementation plan for **Spendly: An AI-Powered Android Finance Tracker with Gamification**, built to match the approved FYP1 proposal. Every phase maps back to a section of that report so the finished app can be defended against what was proposed.

**How to use this:** one phase per Claude Code session. Finish a phase, run its "Done when" checks, commit, then move on. Don't start a phase before the previous one passes its checks — most of the ordering exists to protect the offline-first architecture, and skipping ahead is how that gets quietly broken.

---

## Locked decisions (Phase 0 sets these; don't change them later)

These aren't in the report but must be decided once and held, or the codebase drifts.

| Decision | Choice | Why |
|---|---|---|
| State management | **Riverpod** | Testable without a widget tree, good for the unit-testing requirement. Provider is a simpler alternative if you prefer — pick one now, never mix. |
| Architecture style | **Layered (clean-ish)**: `presentation / domain / data` | Maps 1:1 onto the three-layer architecture in Report §3.3.1, so the code structure matches what you wrote. |
| Local DB | **Hive**, AES-encrypted | Report §3.4 names Hive. Encryption satisfies §3.2.2 "encrypted at rest". |
| Source of truth | **Hive is authoritative. Firestore is a sync target.** | This is the whole offline-first claim. Never read Firestore on a critical path. |
| Deletes | **Soft delete (tombstones)** | Hard deletes can't sync — a deleted row on one device looks like a missing row, not a deletion. |
| Conflict resolution | **Last-write-wins on `updatedAt`** | Report §3.3.3 describes opportunistic sync; LWW is the simplest defensible rule for single-user, and Report §1.4.3 already scopes out multi-device realtime sync. |

### Folder structure

```
lib/
  core/           constants, typed error classes, DI setup
  domain/
    entities/     plain Dart models (no Hive/Firebase imports)
    repositories/ abstract interfaces only
    services/     GamificationEngine, BudgetEvaluator (pure logic)
  data/
    local/        Hive boxes, type adapters, local data sources
    remote/       Firebase client, Gemini client
    repositories/ implementations of the domain interfaces
  presentation/
    screens/
    widgets/
    providers/
```

The rule that makes Report §3.2.2 "Maintainability" true: **`domain/` imports nothing from `data/`.** The AI layer, storage layer and gamification logic each sit behind an interface, so any one can be swapped without touching the other two. If Claude Code ever writes `import 'package:hive...'` inside `domain/`, that's a bug.

---

## Phase 0 — Environment, scaffold, architecture skeleton

**Goal:** an empty but correctly-shaped app that builds and runs on an emulator.

**Build:**
- `flutter create spendly`, Android-only config, min SDK 21+
- Folder structure above, with placeholder files so the shape is visible
- Riverpod, Hive, `flutter_secure_storage`, `intl`, `fl_chart` (or similar) added to `pubspec.yaml`
- Git repo initialised, `.gitignore` covering `google-services.json`, `.env`, any key files
- `CLAUDE.md` in root

**Done when:** app launches to a blank home screen on an emulator; `flutter analyze` is clean; nothing secret is tracked by git.

**Maps to:** Report §3.1 (Agile setup), §3.4 (tools)

---

## Phase 1 — Domain models + encrypted local storage

**Goal:** the data foundation. No UI yet.

**Build:**
- Entities: `Transaction`, `Category`, `Budget`, `GamificationState`, `Badge`, `AdviceRecord`
- **Every syncable entity carries:** `id` (UUID), `userId`, `createdAt`, `updatedAt`, `isDeleted`, `syncStatus`
- Hive type adapters + box initialisation
- AES encryption: generate a key once, store it in `flutter_secure_storage` (backed by Android Keystore), pass it as `HiveAesCipher`
- Abstract repository interfaces in `domain/repositories/`, Hive-backed implementations in `data/repositories/`
- Seed a default category set on first launch

**Critical detail:** include `userId` in the models *now*, even though auth doesn't arrive until Phase 5. Use a local placeholder value until then. Retrofitting a user ID into a populated database later is genuinely painful.

**Done when:** unit tests prove CRUD round-trips through Hive; the `.hive` file on disk is unreadable as plain text; `domain/` has zero Hive imports.

**Maps to:** Report §3.3.1 (local data layer), §3.2.2 (Security — encrypted at rest)

---

## Phase 2 — Transaction Manager + manual entry UI

**Goal:** first genuinely usable version. Fully offline.

**Build:**
- Add / edit / delete (soft) / list transactions
- Manual entry form: amount, income-or-expense, category, date, optional note
- Home screen: current balance, recent transactions list
- Riverpod providers wiring UI to the repository

**Usability target starts here:** a first-time user must reach a saved transaction in under 60 seconds with no instructions (Report §3.2.2). That means a visible add button on the home screen, sensible defaults (today's date, last-used category), and no mandatory fields beyond amount and category.

**Done when:** you can add, edit and delete transactions with the emulator in airplane mode, and they survive an app restart. Time yourself on a fresh install: first transaction saved in under 60s.

**Maps to:** Report §3.3.2 (Transaction Manager), §3.2.1, §3.5.4 (Usability)

---

## Phase 3 — Categories + Budget Manager

**Goal:** spending limits with visible feedback.

**Build:**
- Category management: create, edit, delete custom categories (icon + colour)
- `Budget` entity wired up: limit per category or overall, per period (weekly/monthly)
- `BudgetEvaluator` as **pure logic in `domain/services/`** — takes transactions + budgets, returns status. No storage or UI imports; this makes it directly unit-testable.
- Visual warning states: approaching limit (~80%) and exceeded, shown on home and category views

**Done when:** setting a limit and crossing it produces a visible warning with no network; `BudgetEvaluator` has unit tests covering under/near/over/exactly-at-limit.

**Maps to:** Report §3.3.2 (Budget Manager), §3.2.1

---

## Phase 4 — Reports and visualisation

**Goal:** weekly / monthly / yearly visual reports.

**Build:**
- Report screens with period switching
- Charts: spend by category (pie), spend over time (bar/line)
- **Aggregate cache** — this is a requirement, not an optimisation. Report §3.5.1 explicitly commits to reports being "generated from locally cached aggregates rather than being recalculated from the full transaction history on every view." Store rolled-up per-period totals, update them when transactions change, and read those for the charts.

**Done when:** reports open in under 2 seconds with 1,000+ seeded transactions (test this with generated data — it's the §3.2.2 performance bar and the scalability claim); charts render correctly when a period has no data.

**Maps to:** Report §3.5.1 (Performance), §3.2.2 (Scalability)

---

## Phase 5 — Firebase Authentication

**Goal:** real user identity, without breaking offline-first.

**Build:**
- Firebase project wired up; `google-services.json` in place and gitignored
- Email/password registration and login via Firebase Auth
- Migrate the Phase 1 placeholder `userId` to the real Firebase UID
- **Session persists offline.** A logged-in user who opens the app with no connection goes straight to their data. Auth gates first entry, not every launch.
- No plaintext credentials stored anywhere on device (§3.2.2)

**Done when:** register → close app → airplane mode → reopen → still logged in, data intact. That test is the whole point of this phase.

**Maps to:** Report §3.2.1, §3.5.2 (Security — authentication)

---

## Phase 6 — Sync Manager

**Goal:** local ↔ Firestore reconciliation. The hardest phase; that's why it comes before the AI features.

**Build:**
- Connectivity monitoring
- Push: everything with `syncStatus == pending` uploads when a connection appears
- Pull: remote changes newer than local `updatedAt` come down
- Last-write-wins on `updatedAt`; tombstones (`isDeleted`) propagate as deletions
- Firestore security rules: a user can read/write **only** documents under their own UID
- Retry with backoff; sync failure must never block or corrupt local writes

**Done when:** offline edits queue and then sync on reconnect; a soft-deleted record disappears after sync rather than reappearing; killing the app mid-sync loses nothing; the security rules reject cross-user access (test this deliberately).

**Maps to:** Report §3.3.2 (Sync Manager), §3.3.1, §3.5.2

---

## Phase 7 — Receipt Scanner Module (Gemini vision)

**Goal:** the headline feature. Photo → structured transaction → **user confirms** → saved.

**Build:**
- Camera / gallery capture
- Client-side image compression *before* upload (Report §3.5.1 commits to this)
- Gemini multimodal call with a **strict JSON schema** in the prompt: `{ merchant, totalAmount, currency, date, suggestedCategory, confidence }`
- Robust parsing: malformed or partial responses must degrade to a pre-filled manual form, never crash
- **Confirmation screen showing every extracted field, editable, before anything is saved.** Never auto-save. This is both §3.5.4 (user control) and §3.5.3 (ethics).
- Receipt images not retained locally after processing (§3.5.2)
- Graceful offline behaviour: feature is clearly unavailable, rest of the app unaffected

**Decision you need to make in this phase — API key placement:**
An API key shipped inside an APK is extractable, so a key in the client is a genuine security weakness. Two honest options:
- **Better:** proxy Gemini calls through a Firebase Cloud Function, so the key lives server-side. Requires the Blaze plan for outbound network calls.
- **Acceptable for a capstone:** key in the client with API restrictions applied, *documented as a known limitation* in your CP2 report.

Pick deliberately and write down why — this is exactly the kind of thing a supervisor or examiner probes.

**Note:** you already proved this feature works during CP1 (the Week 5/6 feasibility prototype). Reuse what you learned there, particularly the strict-output prompting that fixed the inconsistent extraction.

**Done when:** ten real receipt photos extract usable merchant/amount/date; a deliberately bad image falls back cleanly to manual entry; nothing saves without an explicit user tap.

**Maps to:** Report §1.3.1, §3.3.2, §3.3.3, §3.5.1–3.5.4

---

## Phase 8 — Gamification Engine

**Goal:** XP, coins, badges, streaks that reward real budgeting behaviour.

**Build:**
- `GamificationEngine` as **pure logic in `domain/services/`**, driven by events raised by the Transaction and Budget managers — not called directly from UI. This decoupling is the §3.2.2 maintainability requirement in practice.
- XP and coins awarded for: logging a transaction, staying within a limit for a period, consistent daily logging
- Login streaks with a defined break rule (decide and document: does a missed day reset to zero, or decay?)
- Badges with explicit unlock criteria
- **Immediate feedback**: the reward appears right after the action that earned it, not only on a separate stats page (§3.5.4, visibility of system status)

**Ethical constraint from your own report (§3.5.3):** rewards attach to healthy budgeting behaviour, **not** to time-in-app or open-count. Don't add "opened the app 5 days in a row" style engagement rewards — you explicitly argued against that, and a marker who reads both will notice.

**Done when:** engine unit tests cover each award rule including edge cases (midnight boundaries, timezone changes, backdated transactions); rewards animate immediately on the triggering action; engine has zero UI or storage imports.

**Maps to:** Report §1.3.3, §3.3.2, §3.5.3, §3.5.4

---

## Phase 9 — Advice Generator

**Goal:** personalised budgeting advice from the user's own patterns.

**Build:**
- Build an **aggregated** spending summary (category totals, period trends, limit adherence) — never the raw full transaction history. Report §3.5.3 commits to sending only what's necessary.
- Gemini text call with that summary; return 2–4 concrete, specific suggestions
- Cache advice against a summary hash so identical data doesn't trigger repeat API calls
- Clear labelling that this is AI-generated guidance, not financial advice
- Offline: show the last cached advice with its timestamp, not an error

**Done when:** advice references the user's actual categories and numbers rather than generic tips; the exact payload sent to Gemini is inspectable and contains no individual transaction rows.

**Maps to:** Report §1.3.3, §3.3.2, §3.5.3

---

## Phase 10 — Security, privacy and ethics surfaces

**Goal:** make the commitments in §3.5.2 and §3.5.3 visible in the product, not just in the report.

**Build:**
- Onboarding/consent screen: specifically what is sent to Gemini, when, and why — not a generic privacy blob (§3.5.3 explicitly rejects the generic version)
- Settings toggles: disable AI features entirely, clear cached advice, delete all local data
- Verify HTTPS-only across all network calls
- Confirm no credentials, keys or receipt images persist on device
- PDPA-aligned privacy notice

**Done when:** a user can use the whole app with AI features switched off; the consent text names Gemini and states what leaves the device.

**Maps to:** Report §3.5.2, §3.5.3

---

## Phase 11 — Testing pass against the non-functional bars

**Goal:** evidence for CP2. Your NFRs were written as measurable targets — measure them.

**Build:**
- Unit tests: `BudgetEvaluator`, `GamificationEngine`, sync conflict resolution, Gemini response parsing
- Integration tests: full flows (add → sync → reappear; scan → confirm → save → reward)
- **Performance:** time core actions on a mid-range device with a large dataset. Target <2s (§3.2.2).
- **Reliability:** full offline pass — everything except the two AI features must work.
- **Usability:** run the 60-second first-transaction test on 3–5 real people who haven't seen the app. Record times and where they hesitate. This is real, citable CP2 evidence.

**Done when:** each NFR from §3.2.2 has a recorded measured result, pass or fail. A documented near-miss with analysis is worth more than an unverified claim.

**Maps to:** Report §3.1 (testing stage), §3.2.2 (all NFRs)

---

## Phase 12 — Polish and release build

**Goal:** something demonstrable.

**Build:**
- Empty states, loading states, error states throughout
- App icon, splash, consistent theming
- Accessibility pass: contrast, tap target sizes, text scaling
- Signed release APK
- Demo dataset for presentations (don't demo on an empty app)
- README + architecture diagram matching §3.3.1

**Done when:** release APK installs and runs on a physical device; a cold-start demo path is rehearsed end to end.

---

## Ordering rationale (worth knowing, and worth saying in your viva)

- **Local core before network, network before AI.** Building the offline path first is what makes the offline-first claim structurally true rather than retrofitted. If auth or sync came first, connectivity assumptions leak into the critical path and are very hard to remove later.
- **Sync before the AI features** because it's the highest-risk piece of infrastructure and everything downstream sits on it. The AI risk was already retired by your CP1 prototype, so it doesn't need to come first.
- **Gamification after budgets** because it's event-driven off transaction and budget outcomes — it has nothing to react to until those exist.
- **Ethics surfaces (Phase 10) as their own phase** rather than sprinkled in, so the commitments in §3.5.3 get built deliberately instead of being assumed.

## Per-phase habit

1. Start a Claude Code session, state the phase
2. Build
3. Run the "Done when" checks — actually run them, don't assume
4. Commit with the phase number in the message
5. If a locked decision changed, update `CLAUDE.md` before the next phase
6. Log it in your CP2 logbook while it's fresh

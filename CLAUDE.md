# Spendly — Project Context for Claude Code

Read this fully before writing any code. It is the authoritative brief for this project.

---

## 1. What this is, and the constraint that matters most

Spendly is an AI-powered Android budgeting app for students and young adults in Malaysia. It automates expense recording via AI receipt scanning, works fully offline for all core features, and uses gamification plus AI-generated advice to sustain long-term engagement.

**This is a university capstone project (FYP / Capstone Project 2).** A proposal has already been written, submitted and graded. The code must match what that document promised. This changes how you should behave:

- **Do not silently "improve" on the specified stack or architecture.** If Hive, Firebase, Flutter or Gemini seems like the wrong tool for something, say so and explain the tradeoff — but do not substitute. The report names these specifically and the final submission is assessed partly on whether the build matches the proposal.
- **If you think something in this brief is wrong or will not work, raise it before building, not after.** A flagged deviation with reasoning is fine. An unflagged one creates a mismatch between the code and a submitted document.
- Several constraints below look like ordinary preferences but are actually written commitments in a graded report. They are marked **[REPORT COMMITMENT]**. Treat those as non-negotiable.

The full phase-by-phase build plan lives in `SPENDLY_BUILD_PLAN.md`. Work one phase at a time.

---

## 2. Tech stack (fixed)

| Layer | Technology |
|---|---|
| Client | Flutter (Dart), **Android only** |
| Local storage | **Hive**, AES-encrypted |
| Backend | Firebase — Authentication, Cloud Firestore, Cloud Storage |
| AI | **Google Gemini** (multimodal: receipt OCR *and* text advice from the same API) |
| State management | **Riverpod** |
| Charts | fl_chart |
| Secrets | flutter_secure_storage (Android Keystore) |

No iOS. No web. Do not propose cross-platform expansion — scope exclusion is stated in the report.

---

## 3. Architecture — offline-first, three layers

**[REPORT COMMITMENT]** The single most important architectural rule:

> **Hive is the source of truth. Firestore is a sync target, not a data source.**

Every core read and write hits local storage first. Firestore syncs opportunistically in the background. **No feature on the critical path may depend on connectivity** — the only two exceptions are AI receipt scanning and AI advice generation, which obviously need the network and must degrade gracefully when it is absent.

This inverts the usual Firebase pattern. Do not enable Firestore offline persistence and treat it as the local layer. Do not write UI that reads from Firestore streams. If you find yourself doing either, stop.

### Three layers

1. **Presentation** — Flutter UI, Riverpod providers
2. **Domain** — entities, abstract repository interfaces, pure business logic services
3. **Data** — Hive (local), Firebase + Gemini (remote), repository implementations

### Folder structure

```
lib/
  core/           constants, error types, Result type, DI setup
  domain/
    entities/     plain Dart models — no Hive, no Firebase imports
    repositories/ abstract interfaces only
    services/     GamificationEngine, BudgetEvaluator — pure logic
  data/
    local/        Hive boxes, type adapters, local data sources
    remote/       Firebase client, Gemini client
    repositories/ implementations of domain interfaces
  presentation/
    screens/
    widgets/
    providers/
```

**Hard rule:** `domain/` imports nothing from `data/`. Dependencies point inward. This is what makes the report's maintainability requirement true — the AI layer, storage layer and gamification logic each sit behind an interface and can be replaced independently. If you write `import 'package:hive...'` inside `domain/`, that is a bug, not a shortcut.

---

## 4. Data models

Concrete field lists. Use these exactly unless there is a reason to change, in which case flag it first.

**Money is stored as `int` in minor units (sen), never `double`.** Floating-point money accumulates rounding errors across aggregation, which would show up in the reports. Convert to display format at the UI boundary only.

### Every syncable entity carries these fields

```dart
String id;            // UUID v4
String userId;        // Firebase UID (see §4.1)
DateTime createdAt;
DateTime updatedAt;   // drives last-write-wins conflict resolution
bool isDeleted;       // soft delete / tombstone — never hard delete
SyncStatus syncStatus; // { pending, synced }
```

### Transaction
```dart
String id, userId;
int amountMinor;              // always positive; direction comes from `type`
TransactionType type;         // { income, expense }
String categoryId;
DateTime date;                // user-editable transaction date
String? note;
TransactionSource source;     // { manual, scanned }
// + createdAt, updatedAt, isDeleted, syncStatus
```

### Category
```dart
String id, userId, name;
int iconCode, colorValue;
bool isDefault;               // seeded defaults vs user-created
// + createdAt, updatedAt, isDeleted, syncStatus
```

### Budget
```dart
String id, userId;
String? categoryId;           // null = overall budget across all categories
int limitAmountMinor;
BudgetPeriod period;          // { weekly, monthly }
DateTime startDate;
// + createdAt, updatedAt, isDeleted, syncStatus
```

### GamificationState (one per user)
```dart
String userId;                // primary key
int xp, coins, level;
int currentStreak, longestStreak;
DateTime? lastActivityDate;
List<String> unlockedBadgeIds;
// + updatedAt, syncStatus
```

### Badge (static catalogue, not synced)
```dart
String id, name, description, criteriaDescription;
int iconCode;
```

### AdviceRecord
```dart
String id, userId;
DateTime generatedAt;
String summaryHash;           // hash of the aggregate summary sent to Gemini
List<String> adviceItems;
```

### PeriodAggregate (report cache — see §6 Performance)
```dart
String id;                    // composite: userId_periodType_periodKey_categoryId
String userId;
PeriodType periodType;        // { weekly, monthly, yearly }
String periodKey;             // e.g. "2026-09", "2026-W36", "2026"
String? categoryId;           // null = all categories for that period
int totalIncomeMinor, totalExpenseMinor;
int transactionCount;
DateTime updatedAt;
```

### 4.1 userId before authentication exists

Auth arrives in Phase 5, but `userId` must be present in the models from Phase 1. Use a local placeholder until then, and migrate to the real Firebase UID in Phase 5. Retrofitting a user ID into a populated database is painful; adding the field early costs nothing.

---

## 5. The six core components

| Component | Responsibility | Lives in |
|---|---|---|
| **Transaction Manager** | create / edit / soft-delete / categorise transactions | `data/repositories` + `presentation` |
| **Receipt Scanner Module** | capture → compress → Gemini → parse JSON → hand to user for confirmation | `data/remote` + `presentation` |
| **Budget Manager** | evaluate spend against limits, produce warning states | `domain/services/BudgetEvaluator` (pure) |
| **Gamification Engine** | XP, coins, badges, streaks from behavioural events | `domain/services/GamificationEngine` (pure) |
| **Advice Generator** | aggregate summary → Gemini → personalised suggestions | `data/remote` |
| **Sync Manager** | connectivity monitoring, local↔Firestore reconciliation | `data/repositories` |

`BudgetEvaluator` and `GamificationEngine` are **pure logic with no storage or UI imports**. They take data in and return results. This makes them directly unit-testable, which the report commits to.

---

## 6. Requirements as acceptance criteria

### Functional
- Register / login (Firebase Auth), session persists offline
- Manual transaction entry: amount, type, category, date, optional note
- Receipt photo → Gemini extraction → **user confirms** → saved
- Custom categories: create, edit, delete
- Spending limits per category or overall, with visual warnings approaching and exceeding
- Weekly / monthly / yearly visual reports
- XP, coins, badges for defined budgeting behaviours; login streaks
- Personalised AI advice derived from the user's own spending
- **Everything above works fully offline except AI scanning and AI advice**, with local changes syncing when connectivity returns

### Non-functional — **[REPORT COMMITMENT]**, these are measured in Phase 11

| Requirement | Target |
|---|---|
| **Performance** | Core actions (add transaction, open home, open report) complete in **under 2 seconds** on a mid-range Android device |
| **Reliability** | All core functions work with **zero connectivity**, except the two AI features |
| **Security** | Local data encrypted at rest; HTTPS only; **no plaintext credentials on device** (OWASP Mobile Top 10 baseline) |
| **Usability** | A first-time user saves their first transaction in **under 60 seconds** with no instructions |
| **Scalability** | Stays responsive with multi-year transaction history |
| **Maintainability** | AI layer, storage layer and gamification logic independently replaceable |

**Performance detail [REPORT COMMITMENT]:** reports are generated from **locally cached aggregates** (`PeriodAggregate`), not by recalculating over the full transaction history on each view. Update aggregates when transactions change. Do not write naive full-table scans for the report screens.

**Usability detail:** the 60-second target implies a visible add button on the home screen, sensible defaults (today's date, last-used category), and no mandatory fields beyond amount and category.

---

## 7. Ethical constraints — **[REPORT COMMITMENT]**

These are written commitments in a graded document, and they cut against common defaults. Follow them exactly.

1. **AI extraction is always confirm-before-save.** The receipt scanner shows every extracted field, editable, and saves only on an explicit user tap. Never auto-save extracted data. This is both a user-control and an ethics commitment.

2. **Gamification rewards healthy budgeting behaviour, not engagement metrics.** Award XP/coins for logging transactions, staying within limits, and consistent budgeting. **Do not** add rewards for time spent in the app, app opens, or session length. The report explicitly argues against incentivising compulsive checking. This is the opposite of typical engagement-loop design — do not add those patterns.

3. **Only aggregated data goes to Gemini for advice.** Send category totals, period trends and limit adherence. **Never send raw individual transaction rows or full history.** Data minimisation is a stated commitment.

4. **Consent must be specific, not generic.** The disclosure names Gemini, states exactly what leaves the device and when. A generic privacy blob does not satisfy this — the report explicitly rejects that.

5. **Receipt images are not retained locally after processing.**

6. Users can disable AI features entirely and still use the whole app.

---

## 8. Coding conventions

- **Soft deletes only.** Set `isDeleted = true` and bump `updatedAt`. Hard deletes cannot sync — a deleted row on one device is indistinguishable from a missing one.
- **Always update `updatedAt`** on any mutation. Conflict resolution depends on it.
- **Set `syncStatus = pending`** on any local mutation; the Sync Manager clears it.
- Sync failures must never block or corrupt local writes. Local write succeeds first, sync is best-effort.
- Prefer explicit error handling over silent catches. A swallowed sync error is a data-loss bug.
- Null-safety throughout; no `!` unless provably safe.
- Widget files stay presentational — business logic belongs in `domain/services` or repositories.
- Write unit tests alongside pure logic (`BudgetEvaluator`, `GamificationEngine`, sync conflict resolution, Gemini response parsing), not as an afterthought.

### Secrets and git
- `google-services.json`, any `.env`, and API keys are **gitignored from Phase 0**.
- Never hardcode an API key in tracked source.
- Gemini key placement is an open decision — see §9.

---

## 9. Open decisions to raise, not silently resolve

**Gemini API key placement.** A key shipped inside an APK is extractable, so a client-side key is a genuine security weakness given the app handles financial data. Two honest options:
- **Better:** proxy Gemini calls through a Firebase Cloud Function so the key stays server-side (requires Blaze plan for outbound calls).
- **Acceptable for a capstone:** key in client with API restrictions, *documented as a known limitation* in the CP2 report.

This must be decided deliberately in Phase 7 and written down. Do not just pick one silently.

**Streak break rule.** Does a missed day reset the streak to zero, or decay it? Decide and document in Phase 8.

---

## 10. Common commands

```bash
flutter run                                              # run on emulator/device
flutter analyze                                          # static analysis — keep clean
flutter test                                             # unit + widget tests
dart run build_runner build --delete-conflicting-outputs # Hive adapters, codegen
flutter build apk --release                              # release build
```

---

## 11. Working rhythm

One phase per session, following `SPENDLY_BUILD_PLAN.md`:

1. State which phase is starting
2. Build it
3. **Actually run the phase's "Done when" checks** — do not assume they pass
4. Commit with the phase number in the message
5. If a decision in this file changed, update this file before the next phase

Where a phase's requirements are ambiguous, ask rather than guess. A wrong assumption baked into the data layer or sync logic is expensive to unwind later.

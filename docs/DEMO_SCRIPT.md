# Spendify — Demo script (Phase 12 Part E)

A run sheet for the CP2 live demo. Rehearse this end to end, including the
airplane-mode segment, before presenting it for real.

---

## 1. Before you start

1. **Load the demo dataset** (fresh install, or after Settings → "Delete all
   local data"):

   ```bash
   flutter run --dart-define=DEMO_SEED=true --dart-define=GEMINI_API_KEY=your_key_here
   ```

   Omit `GEMINI_API_KEY` if you aren't demoing the AI features — everything
   else in the script still works, and the receipt-scan / Insights steps just
   get skipped.

   The seed is inert unless `DEMO_SEED=true` is passed, never runs in a
   release build, and does nothing if any transaction already exists — so it
   is safe to leave in the launch command for the whole demo session; it will
   not re-seed or clobber anything after the first run. There is no real
   sign-in involved: with no persisted session, `main()` runs the app as a
   local demo user (`demo@spendify.app`) so it opens straight on the home
   screen.

2. **What the seed loads** (`lib/core/dev/demo_seed.dart`, verified by
   `test/dev/demo_seed_test.dart`):
   - ~120 days of realistic transaction history across all 8 default
     categories, including two income deposits a month ("Allowance" /
     "Part-time").
   - **Three budgets this month, one in each warning state**: Entertainment
     (safe), Groceries (approaching), Food (exceeded) — so the warning banner
     and the coloured budget list are both populated without you doing
     anything live.
   - **Gamification at level 5**, 9 badges unlocked, a 5-day current streak
     (14-day best) — the Rewards screen looks lived-in, not a fresh install.
3. **Charge the device and set it to airplane mode readiness** — you'll toggle
   it live in step 6.
4. Know the device + OS version you're presenting on (goes in the report next
   to the performance numbers).

---

## 2. The script

### Opening (30 seconds)

> "Spendify is an offline-first budgeting app — everything you're about to see,
> except two clearly-marked AI features, works with zero network connection.
> Local data comes first; the cloud is a backup, not a dependency."

Open the app on the **home screen**. Point out: the balance card, the budget
warning banner (already showing "Food budget is over its monthly limit"), the
recent-transactions list, and the single obvious **Add** button.

### 1. Manual entry — the 60-second story (CLAUDE.md §6 usability target)

> "A first-time user should be able to record a transaction in under 60
> seconds with zero instructions."

- Tap **Add**. Note today's date and a category are already selected — no
  mandatory fields beyond amount and category.
- Type an amount (`12.50`), leave the default category, tap **Add
  transaction**.
- It's back on the home screen instantly, the new row is at the top, and a
  small reward toast appears (gamification reacting to the log).

### 2. Receipt scanning (needs the Gemini key — skip if not configured)

> "The app can also read a receipt photo instead of typing."

- Tap the small scan FAB above Add.
- Take a photo of a real receipt (have one ready — a printed one scans most
  reliably).
- Gemini extracts amount / date / merchant. **Every field is shown, editable,
  and nothing saves until you tap Save** — call this out explicitly, it's a
  CLAUDE.md §7 ethics commitment, not an incidental UI choice.
- Tap **Save transaction**.

### 3. Budget warning

> "Budgets warn you before and after you cross a limit."

- Open **Budgets** (toolbar icon). Show the three seeded budgets: Entertainment
  green/safe, Groceries orange/approaching, Food red/exceeded — each state has
  an icon and a word, not just a colour.
- Tap back to Home, tap the warning banner, land back on Budgets — show it's
  a live shortcut, not decoration.

### 4. Reports

> "Reports don't recompute your whole history — they read a maintained
> cache, so they open instantly no matter how much data you have."

- Open **Reports**. Switch Weekly → Monthly → Yearly. Point at the pie chart
  + the "by category" list underneath it (same numbers as text — colour is
  never the only signal).

### 5. Gamification

> "Rewards are for budgeting behaviour — logging, staying under limits,
> consistency — never for how often you open the app."

- Open the overflow menu → **Rewards**. Show the level bar (level 5), coins,
  the 5-day streak, and the badge grid (9 unlocked, a few still locked and
  greyed with a lock icon).

### 6. AI advice (needs the Gemini key)

> "Advice is generated from an aggregated summary of your spending — never
> your raw transactions."

- Open the overflow menu → **Insights**.
- Show the advice cards, the "Last updated" timestamp, and — this is the
  point to linger on — **Settings → "What's sent to Gemini"**, which shows
  the *exact* JSON payload the app would send. No merchant names, no notes, no
  identity, rounded numbers.

### 7. Offline — the centrepiece

> "Now I'm going to turn off networking entirely and show you this all still
> works."

- Put the device in **airplane mode**, visibly (turn the screen so the
  audience sees the airplane icon appear).
- Add another transaction the same way as step 1 — works identically.
- Open Reports, Budgets, Rewards — all render, all instant.
- Open **Insights** (or attempt receipt scan) — show the honest "you're
  offline" message with cached advice and its timestamp still visible, no
  crash, no spinner that never resolves.
- Kill the app fully (swipe away from recents) and relaunch **while still in
  airplane mode** — it lands straight back on the home screen with the
  session and data intact, no login prompt, no wait on a network call.
- Turn airplane mode back off. If sync is configured, point at the sync
  status icon in the AppBar quietly flipping to "backed up".

### Closing (15 seconds)

> "Everything except two labelled AI features just worked with no network at
> all, because Hive — the local encrypted database — is the source of truth,
> not Firestore."

---

## 3. If something goes wrong live

| Symptom | Likely cause | Recovery |
|---|---|---|
| Scan fails / times out | no real network, or key not passed | tap "Enter manually", continue the script — this is the designed fallback, not a crash |
| Insights shows "AI insights are off" | no `GEMINI_API_KEY` on this run | expected without the key; narrate it as the designed off-state rather than skipping past it |
| A number looks off after edits during rehearsal | aggregate cache drifted | Settings → "Rebuild report data" |
| Want a clean slate again | — | Settings → "Delete all local data", relaunch with the same `DEMO_SEED=true` command |

---

## 4. What needs a network for this demo

Only receipt scanning (step 2) and AI advice (step 6) — both call Gemini.
Everything else, including the entire step 7 offline segment, is local. Sync
(if a Firebase project is configured) is opportunistic and never blocks
anything shown above.

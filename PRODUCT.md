# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Students and young adults in Malaysia managing their own day-to-day personal
budget. The core job is recording everyday spending — manually or from a
receipt photo — reliably enough that the habit survives real-world friction:
a first-time user must be able to save their first transaction in under 60
seconds with no instructions (a written, measured requirement, not an
aspiration). Beyond that first save, the same user relies on budgets,
reports and gamification to keep logging over weeks and months rather than
abandoning the app after a few days, which is the usual failure mode for
budgeting apps in this category.

## Product Purpose

Spendify (renamed 2026-09-14 from "Spendly" — see Brand Commitments) is an
AI-assisted, offline-first Android budgeting app. It automates expense
recording via receipt-photo AI extraction, tracks spending against
category/overall budgets with visual warnings, generates personalised AI
advice from the user's own aggregated spending, and uses gamification
(XP, coins, badges, login streaks) to sustain long-term engagement. Success
is a user who keeps logging real transactions over time and trusts the app
enough to check it regularly without feeling tracked or manipulated into
doing so.

## Positioning

Two structural commitments differentiate this from a typical budgeting app,
and both are load-bearing for design, not just backend plumbing a screen
happens to sit on top of:

1. **Genuinely offline-first.** Every core feature — add/edit/delete a
   transaction, categories, budgets and their warnings, all reports,
   gamification — works with zero connectivity. Only receipt-scanning and
   AI-advice generation need the network, and both must degrade with a
   plain, honest message rather than a spinner that never resolves or a
   raw error. Local storage is the source of truth; the cloud backup is
   never on the critical path of using the app.
2. **Gamification and AI operate under explicit ethical limits.** Rewards
   attach only to budgeting behaviour (logging, staying under a limit,
   consistency) — never to opening the app, session length, or any other
   engagement metric. AI advice is generated from aggregated, rounded
   numbers only, never raw transactions, merchant names or notes. Receipt
   photos are never retained after processing. AI can be switched off
   entirely and the rest of the app is unaffected. A design that makes
   gamification feel like a slot machine, or that quietly implies the app
   is watching more than it says, would contradict the product's own
   stated commitments.

## Operating Context

Originally built as a university capstone project (Final Year Project /
Capstone Project 2) against a written, graded proposal, so the build had to
match specific pre-committed decisions (tech stack, architecture, and a set
of ethics constraints the proposal marks as non-negotiable report
commitments). As of this session: the product has just been renamed from
"Spendly" to "Spendify"; a real Firebase project and a real Gemini API key
now exist; the app is **pre-launch** — no public app-store listing, used so
far only by its developer for testing, grading and demo purposes. No other
audience, team, or stakeholder has been described.

## Capabilities and Constraints

**Confirmed functionality:** register/sign in (Firebase Auth, session
persists offline); manual transaction entry (amount, type, category, date,
optional note) with sensible defaults (today's date, last-used category);
receipt photo → AI extraction → user confirms every field before saving;
custom categories (create/edit/delete, icon + colour); spending limits per
category or overall (weekly/monthly) with "approaching" and "exceeded"
visual states; weekly/monthly/yearly reports from a cached aggregate (never
a full re-scan as data grows); XP/coins/levels/badges/streaks; personalised
AI advice from aggregated spending; opportunistic Firestore backup/restore.

**Fixed stack** (not open to this redesign to change): Flutter/Dart,
Android only (no iOS, no web); Hive (AES-encrypted local storage); Firebase
(Auth + Firestore); Google Gemini (receipt OCR + text advice, one shared
key); Riverpod; fl_chart for data visualisation.

**Architecture constraint relevant to visual work:** three layers
(presentation / domain / data); presentation is Flutter UI + Riverpod only,
with no business logic — a visual redesign should not need to touch
`domain/` or `data/` at all, only `presentation/` and `core/theme/`.

**Non-functional commitments already measured and evidenced** (a redesign
must not regress these): core actions complete in under 2 seconds; the
first-transaction flow is under 60 seconds; text stays legible and
non-overflowing at 200% system text scale (automated test exists); WCAG AA
contrast; tap targets ≥48×48dp; colour is never the sole signal for a state
(always paired with an icon or label).

**Undecided / explicitly out of scope for now:** dark mode (previously
decided to lock to light only; open to revisit properly in this pass, not
required); the Gemini API-key placement (client-side key vs. a server-side
proxy) is a backend/security decision unrelated to visual design.

## Brand Commitments

- **Name: "Spendify"** — confirmed 2026-09-14, renamed from "Spendly"
  everywhere user-visible and in code-level identifiers. Three things still
  literally read "spendly" as an invisible implementation detail with no
  user-facing effect: the Android package id
  (`com.azatkabulov.spendly`), four persisted local-storage key strings,
  and the filename/alias of the existing release-signing keystore. None of
  these are naming inconsistencies a user or reviewer can see.
- **No existing visual identity.** A placeholder app icon/splash (a plain
  wallet glyph) and a green (`#2E7D32`) seed colour were generated in an
  earlier phase, purely functionally — not a considered brand mark. Both are
  **explicitly open** for this redesign to replace: the user confirmed a
  new colour direction and a new icon/splash are both in scope if the
  design calls for it.
- **Binding constraint, volunteered by the user, recorded as-is:** the
  finished UI must read as professional, restrained, "Apple-caliber" craft
  — smooth motion, considered spacing and typography, no cut corners — with
  **zero Apple branding, logos, or literal iOS chrome**. Navigation
  patterns (nav bars, tab structure, transitions, back behaviour) should
  stay **Android-native** — the user explicitly chose elevated Material
  conventions over transplanting iOS-style bottom tab bars / large titles /
  sheet modals onto Android.

## Evidence on Hand

No real user testimonials, usage analytics, press, or case studies exist —
this is a pre-launch capstone project, and none of that should be fabricated
or implied anywhere in the UI (no fake "trusted by" language, no invented
review scores). The real evidence is the running app itself: every screen
under `lib/presentation/screens/`, the existing (soon-to-be-replaced) theme
in `lib/core/theme/`, and the seeded demo dataset
(`lib/core/dev/demo_seed.dart`) that produces a realistic-looking populated
state for screenshots/demos without real user data.

## Product Principles

1. **Offline-first is structural, not cosmetic.** No screen should visually
   or functionally imply a network dependency it doesn't actually have.
2. **Confirm-before-save, always, for anything AI-extracted.** The "you're
   in control, this is a suggestion" framing should feel considered and
   built-in, not like a bolted-on disclaimer.
3. **Reward the behaviour, not the check-in.** Gamification should feel
   earned and calm — never a guilt mechanic or a slot machine.
4. **Money is serious; the app doesn't have to be grim.** The audience is
   students and young adults — warm and encouraging in tone, not a cold
   corporate finance dashboard.
5. **Never a raw error on screen.** Every empty, loading, and error state
   gets a real, considered design — not a fallback default.

## Accessibility & Inclusion

Established in a prior phase and must be preserved through this redesign:
WCAG AA text contrast (4.5:1 body text minimum); tap targets ≥48×48dp;
usable at 200% system text scale with no overflow (there is an automated
test for this — a redesign must keep it passing); semantic labels on
icon-only controls; colour is never the only signal for a state. Dark mode
is not currently required (see Capabilities and Constraints) but is open to
add properly if the redesign chooses to.

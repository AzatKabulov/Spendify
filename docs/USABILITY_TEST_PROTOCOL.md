# Spendify — Usability Test Protocol (Phase 11, Part D)

Purpose: measure NFR 4 (`CLAUDE.md §6`) —

> **A first-time user saves their first transaction in under 60 seconds with no
> instructions.**

and collect a **System Usability Scale (SUS)** score so the result is
comparable to the studies cited in the CP2 literature review.

This is a **moderated, task-based** test. Run it with **3–5 participants** who
match the target user (Malaysian students / young adults) and who have **never
seen the app**.

---

## 1. Before the session

**You need:**

- A physical Android phone with a **fresh install** of the signed release APK
  (`build/app/outputs/flutter-apk/app-release.apk`). Fully signed out, or use
  the Phase 12 demo account with all data cleared.
- A stopwatch (phone timer is fine) or screen recording with a visible clock.
- This protocol, and one **Results Sheet** (§5) printed per participant.
- The **SUS questionnaire** (§6), one per participant.
- A quiet space, ~10 minutes per participant.

**Prepare the device:**

1. Install the release APK.
2. Open the app once, create/sign into a throwaway account, then
   **Settings → Delete all local data** so the participant starts at a
   genuine empty state (or start fully signed out and let them register — see
   the note in §3).
3. Force-close the app. The participant's first tap is on the launcher icon.

**Do not:**

- Explain any feature.
- Point at the screen.
- Answer "how do I…" questions during the timed task — say *"whatever you think
  makes sense"* and note the question.

---

## 2. Consent script (read aloud)

> "Thanks for helping. I'm testing an app I've built, not you — there are no
> wrong moves. I'll give you one task and time how long it takes. Please think
> aloud as you go: say what you're looking for, what you expect a button to do,
> anything that's confusing. I'll be quiet and just take notes. You can stop any
> time. May I record the screen and audio? It's only used for this project and
> not shared."

Get a yes (verbal is fine for a capstone; a signed slip is better — a blank one
is at the end of this file).

---

## 3. The task

Read this **once**, verbatim, then start the timer when they pick up the phone:

> **"You just spent RM 12.50 on lunch. Record that in the app."**

- **Start the clock** the moment they touch the phone.
- **Stop the clock** the moment the transaction is saved and visible in the
  list (they're back on the home screen and can see "RM 12.50").
- If they get genuinely stuck for **>2 minutes**, stop the timer, mark the task
  **failed**, note where, and then help them so they can continue to the SUS.

**Registration note.** If the participant has to register/sign in first, that is
part of the real first-run experience — **include it in the timing**. If your
supervisor wants the "pure" entry time, run it both ways and record both. State
which in the results.

---

## 4. Also collect (same session, quick)

After the task, before the SUS, ask:

1. "In your own words, what does this app do?"
2. "Was there a moment you weren't sure what to do? When?"
3. "Anything that felt slower than you expected?" (relates to the < 2 s perf NFR)

And — if you have the participant on a physical device anyway — this is a good
moment to run the **on-device performance test** once, which the emulator run in
`TEST_RESULTS.md` §3.4 flagged as a gap:

```
flutter test integration_test/performance_test.dart -d <that-device>
```

Record the device model + Android version + the printed table.

---

## 5. Results Sheet — print one per participant

```
SPENDIFY USABILITY TEST — RESULTS SHEET

Participant ID:  P____        Date: __________      Facilitator: __________
Age band:  [ ] 18–21   [ ] 22–25   [ ] 26–30       Device: ____________________
Uses a budgeting app already?  [ ] no   [ ] yes — which: ____________________
Included registration in the timing?  [ ] yes   [ ] no

------------------------------------------------------------------------------
TASK: "You just spent RM 12.50 on lunch. Record that in the app."
------------------------------------------------------------------------------

Time to first saved transaction:  ______ min ______ sec        ( ____ seconds )

Task outcome:   [ ] completed unaided    [ ] completed with a hint
                [ ] failed (stopped at 2 min)

Number of wrong taps / dead ends: ______

------------------------------------------------------------------------------
STEP LOG  (tick the path they took, note the time at each)
------------------------------------------------------------------------------
[ ] Found the "+ Add" button on home ....................... t = ____ s
[ ] Entered the amount 12.50 ............................... t = ____ s
[ ] Left type = "Expense" (default) ....................... [ ] changed it
[ ] Left category = default ................................ [ ] changed it — to: ______
[ ] Left date = today (default) ........................... [ ] changed it
[ ] Tapped "Add transaction" .............................. t = ____ s
[ ] Saw RM 12.50 in the list (DONE) ....................... t = ____ s

------------------------------------------------------------------------------
HESITATIONS / FRICTION  (quote them where you can)
------------------------------------------------------------------------------
1. ______________________________________________________________________
2. ______________________________________________________________________
3. ______________________________________________________________________

------------------------------------------------------------------------------
THINK-ALOUD — notable quotes
------------------------------------------------------------------------------
______________________________________________________________________
______________________________________________________________________

------------------------------------------------------------------------------
POST-TASK QUESTIONS
------------------------------------------------------------------------------
"What does this app do?"  ______________________________________________
"A moment you weren't sure?"  _________________________________________
"Anything slower than expected?"  _____________________________________
```

---

## 6. System Usability Scale (SUS) — print one per participant

> Standard 10-item SUS (Brooke, 1996). Answer every item, even if unsure.
> 1 = Strongly disagree … 5 = Strongly agree.

```
SPENDIFY — SYSTEM USABILITY SCALE                    Participant P____   Date ______

                                                   SD                     SA
                                                    1     2     3     4     5
 1. I think I would like to use Spendify            [ ]   [ ]   [ ]   [ ]   [ ]
    frequently.
 2. I found Spendify unnecessarily complex.         [ ]   [ ]   [ ]   [ ]   [ ]
 3. I thought Spendify was easy to use.             [ ]   [ ]   [ ]   [ ]   [ ]
 4. I think I would need the support of a          [ ]   [ ]   [ ]   [ ]   [ ]
    technical person to use Spendify.
 5. I found the various functions in Spendify       [ ]   [ ]   [ ]   [ ]   [ ]
    were well integrated.
 6. I thought there was too much inconsistency     [ ]   [ ]   [ ]   [ ]   [ ]
    in Spendify.
 7. I would imagine that most people would learn   [ ]   [ ]   [ ]   [ ]   [ ]
    to use Spendify very quickly.
 8. I found Spendify very cumbersome to use.        [ ]   [ ]   [ ]   [ ]   [ ]
 9. I felt very confident using Spendify.           [ ]   [ ]   [ ]   [ ]   [ ]
10. I needed to learn a lot of things before I     [ ]   [ ]   [ ]   [ ]   [ ]
    could get going with Spendify.

Optional comment: _______________________________________________________
```

### Scoring (do this after)

- **Odd items (1,3,5,7,9):** score = (response − 1)
- **Even items (2,4,6,8,10):** score = (5 − response)
- Sum the 10 adjusted scores (0–40), **multiply by 2.5** → SUS score 0–100.

Interpretation (Bangor et al. / Sauro):

| SUS score | Grade | Adjective |
|---|---|---|
| > 80.3 | A | Excellent |
| 68–80.3 | B/C | Good |
| **68** | — | **Average (the benchmark)** |
| 51–68 | D | OK / poor |
| < 51 | F | Not acceptable |

---

## 7. Analysis to write into `TEST_RESULTS.md §6`

Fill the table, then write 3–5 sentences covering:

1. **Median time to first transaction**, and pass rate against the 60 s target
   (e.g. "4/5 under 60 s, median 41 s").
2. **The one or two friction points** that recurred across participants
   (e.g. "3/5 hesitated at the category dropdown, expecting it to be optional").
3. **Concrete recommended fixes**, phrased as changes (e.g. "make the category
   field show 'Other' pre-selected so it never blocks a save" — but note if that
   conflicts with an existing decision).
4. **Median SUS score** and its grade, compared to the 68 benchmark and to the
   scores cited in your literature review.
5. Anything a participant said about **speed**, cross-referenced with the
   measured performance numbers.

Keep raw sheets and recordings — they are citable primary evidence for CP2.

---

## Appendix — consent slip (optional, print if your ethics process wants it)

```
I agree to take part in a usability test of the Spendify app for a university
capstone project. I understand:
 - the app is being tested, not me;
 - I can stop at any time;
 - my screen and voice may be recorded and used only for this project;
 - my name will not appear in the report (I am "P__").

Name: __________________________   Signature: __________________   Date: ______
```

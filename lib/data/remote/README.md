# `data/remote/`

Network-dependent clients. Everything here must degrade gracefully when offline — only receipt scanning and advice generation are allowed to require connectivity.

- `firebase/` (Phase 5–6) — Auth client, Firestore sync client, Cloud Storage. Firestore is a **sync target**, reconciled by the Sync Manager; it is never a data source for the UI.
- `gemini/` (Phase 7, 9) — multimodal client for receipt OCR and text advice.
  - Receipt scanning: strict JSON schema prompt, robust parsing that falls back to a pre-filled manual form, images not retained after processing.
  - Advice: only aggregated summaries sent — never raw transaction rows (CLAUDE.md §7).
  - API key placement is an open decision to settle in Phase 7 (§9).

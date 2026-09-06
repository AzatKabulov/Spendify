# `data/repositories/`

Concrete implementations of the `domain/repositories/` interfaces, plus the Sync Manager.

Each repository:
- reads and writes **Hive first** — the local write is what succeeds or fails from the caller's point of view;
- applies the CLAUDE.md §8 mutation rules centrally: `delete()` sets `isDeleted = true` (never removes the row), every mutation bumps `updatedAt = now` and sets `syncStatus = pending`, queries filter out `isDeleted` by default;
- converts between DTOs and entities via `data/local/mappers/`.

`SyncManager` (Phase 6): connectivity monitoring, push of `pending` records, pull of newer remote changes, last-write-wins on `updatedAt`, tombstone propagation, retry with backoff. A sync failure must never block or corrupt a local write.

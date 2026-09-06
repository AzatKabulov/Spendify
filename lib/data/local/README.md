# `data/local/`

**The source of truth.** Hive, AES-encrypted.

Planned layout (Phase 1):
- `hive_types.dart` — the single authoritative registry of Hive `typeId` allocations. Never reuse an id.
- `models/` — `@HiveType` / `@HiveField` annotated DTOs (`TransactionModel`, `CategoryModel`, …) plus generated `*.g.dart` adapters. These are the only place Hive annotations appear.
- `mappers/` — `toDomain()` / `toLocal()` conversions between DTOs and `domain/entities/`.
- `hive_bootstrap.dart` — key generation (256-bit, stored in `flutter_secure_storage` / Android Keystore), `HiveAesCipher` box opening, corruption handling, first-launch default-category seeding.
- `sources/` — local data sources wrapping the boxes.

Firestore offline persistence is **not** used as the local layer. Do not read Firestore streams from the UI.

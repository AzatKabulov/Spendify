/// App-wide constants. No feature logic here.
library;

/// Placeholder user id used everywhere until Firebase Auth arrives in Phase 5.
///
/// Every syncable record is stamped with this value now so that Phase 5 has a
/// single, greppable migration point (CLAUDE.md §4.1). Do not read the "current
/// user" from anywhere else in Phases 1–4.
const String kLocalUserId = 'local-user';

/// Key under which the 256-bit Hive encryption key is stored in
/// `flutter_secure_storage` (Android Keystore backed). Changing this string
/// orphans every existing encrypted box, so treat it as permanent.
const String kHiveEncryptionKeyName = 'spendly.hive.aeskey.v1';

/// `flutter_secure_storage` keys for the persisted auth session (Phase 5). The
/// UID is what startup routing reads; neither key ever holds a password.
const String kAuthUidKeyName = 'spendly.auth.uid.v1';
const String kAuthEmailKeyName = 'spendly.auth.email.v1';

/// Names of the encrypted Hive boxes. One box per aggregate.
class HiveBoxes {
  const HiveBoxes._();

  static const String transactions = 'transactions';
  static const String categories = 'categories';
  static const String budgets = 'budgets';
  static const String gamificationState = 'gamification_state';
  static const String adviceRecords = 'advice_records';
  static const String periodAggregates = 'period_aggregates';

  /// Small key/value box for bootstrap flags (e.g. "default categories seeded").
  static const String meta = 'spendly_meta';

  /// Every box name, for bulk open / close / wipe.
  static const List<String> all = <String>[
    transactions,
    categories,
    budgets,
    gamificationState,
    adviceRecords,
    periodAggregates,
    meta,
  ];
}

/// Keys used inside [HiveBoxes.meta].
class MetaKeys {
  const MetaKeys._();

  static const String defaultCategoriesSeeded = 'default_categories_seeded';

  /// Id of the category chosen on the most recent transaction save. Used to
  /// pre-select the category on the add form (CLAUDE.md §6, 60-second target).
  static const String lastUsedCategoryId = 'last_used_category_id';

  /// Set once the PeriodAggregate cache has been built for pre-existing data.
  /// Bump the suffix to force a one-off rebuild after a change to the
  /// aggregation logic. `v2` (Phase 4.1): `PeriodType.daily` aggregates were
  /// added, so every existing install rebuilds once to populate them.
  static const String aggregatesBuilt = 'aggregates_built_v2';

  /// Holds the real Firebase UID that the Phase 1 placeholder `userId` was
  /// migrated to (Phase 5, CLAUDE.md §4.1). Absent = migration not yet
  /// completed; the migration re-runs on every launch until it finishes a full
  /// pass with zero placeholder records remaining.
  static const String userIdMigratedTo = 'user_id_migrated_to';

  /// Per-collection pull cursor for the Sync Manager (Phase 6): the max remote
  /// `updatedAt` (epoch ms) applied so far. Key is `sync_cursor_<collection>`.
  static String syncCursor(String collectionPath) =>
      'sync_cursor_$collectionPath';

  /// Epoch-ms of the last fully successful sync. Drives the "last synced"
  /// label in the UI.
  static const String lastSyncedAt = 'last_synced_at';

  /// Set once a fresh-install restore has completed for this device+account, so
  /// the sign-in flow doesn't re-run the full restore pull every launch.
  static const String restoreCompleted = 'restore_completed';
}

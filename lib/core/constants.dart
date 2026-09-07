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
}

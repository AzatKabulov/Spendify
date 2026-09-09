/// Entity <-> plain `Map` conversion for Firestore backup (Phase 6). The map is
/// JSON-ish with `DateTime` for time fields — `firestore_sync_gateway.dart`
/// converts those to/from Firestore `Timestamp` at the boundary.
///
/// `syncStatus` is a *local* concept and is never written remotely. Anything
/// read back from remote is reconstructed with `syncStatus = synced`.
///
/// Reads are lenient (defensive against a hand-edited console document or a
/// schema that drifted): missing optional fields fall back, unknown enum names
/// fall back, timestamps accept `DateTime` / epoch-ms `int` / ISO `String`.
library;

import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/entities/transaction.dart';

// --- Transaction ---------------------------------------------------------

Map<String, Object?> transactionToRemote(Transaction t) => <String, Object?>{
  'id': t.id,
  'userId': t.userId,
  'amountMinor': t.amountMinor,
  'type': t.type.name,
  'categoryId': t.categoryId,
  'date': t.date,
  'note': t.note,
  'source': t.source.name,
  'createdAt': t.createdAt,
  'updatedAt': t.updatedAt,
  'isDeleted': t.isDeleted,
};

Transaction transactionFromRemote(Map<String, Object?> m) => Transaction(
  id: _str(m['id']),
  userId: _str(m['userId']),
  amountMinor: _int(m['amountMinor']),
  type: _enumByName(TransactionType.values, m['type'], TransactionType.expense),
  categoryId: _str(m['categoryId']),
  date: _date(m['date']) ?? _epoch,
  note: _strOrNull(m['note']),
  source: _enumByName(
    TransactionSource.values,
    m['source'],
    TransactionSource.manual,
  ),
  createdAt: _date(m['createdAt']) ?? _epoch,
  updatedAt: _date(m['updatedAt']) ?? _epoch,
  isDeleted: m['isDeleted'] == true,
  syncStatus: SyncStatus.synced,
);

// --- Category ----------------------------------------------------------

Map<String, Object?> categoryToRemote(Category c) => <String, Object?>{
  'id': c.id,
  'userId': c.userId,
  'name': c.name,
  'iconCode': c.iconCode,
  'colorValue': c.colorValue,
  'isDefault': c.isDefault,
  'createdAt': c.createdAt,
  'updatedAt': c.updatedAt,
  'isDeleted': c.isDeleted,
};

Category categoryFromRemote(Map<String, Object?> m) => Category(
  id: _str(m['id']),
  userId: _str(m['userId']),
  name: _str(m['name']),
  iconCode: _int(m['iconCode']),
  colorValue: _int(m['colorValue']),
  isDefault: m['isDefault'] == true,
  createdAt: _date(m['createdAt']) ?? _epoch,
  updatedAt: _date(m['updatedAt']) ?? _epoch,
  isDeleted: m['isDeleted'] == true,
  syncStatus: SyncStatus.synced,
);

// --- Budget ----------------------------------------------------------

Map<String, Object?> budgetToRemote(Budget b) => <String, Object?>{
  'id': b.id,
  'userId': b.userId,
  'categoryId': b.categoryId,
  'limitAmountMinor': b.limitAmountMinor,
  'period': b.period.name,
  'startDate': b.startDate,
  'createdAt': b.createdAt,
  'updatedAt': b.updatedAt,
  'isDeleted': b.isDeleted,
};

Budget budgetFromRemote(Map<String, Object?> m) => Budget(
  id: _str(m['id']),
  userId: _str(m['userId']),
  categoryId: _strOrNull(m['categoryId']),
  limitAmountMinor: _int(m['limitAmountMinor']),
  period: _enumByName(BudgetPeriod.values, m['period'], BudgetPeriod.monthly),
  startDate: _date(m['startDate']) ?? _epoch,
  createdAt: _date(m['createdAt']) ?? _epoch,
  updatedAt: _date(m['updatedAt']) ?? _epoch,
  isDeleted: m['isDeleted'] == true,
  syncStatus: SyncStatus.synced,
);

// --- GamificationState (doc id == userId) -------------------------------

Map<String, Object?> gamificationToRemote(GamificationState g) =>
    <String, Object?>{
      'userId': g.userId,
      'xp': g.xp,
      'coins': g.coins,
      'level': g.level,
      'currentStreak': g.currentStreak,
      'longestStreak': g.longestStreak,
      'lastActivityDate': g.lastActivityDate,
      'unlockedBadgeIds': g.unlockedBadgeIds,
      'transactionsLogged': g.transactionsLogged,
      'budgetsCreated': g.budgetsCreated,
      'budgetPeriodsWithinLimit': g.budgetPeriodsWithinLimit,
      'scannedTransactionsLogged': g.scannedTransactionsLogged,
      'recentEventIds': g.recentEventIds,
      'updatedAt': g.updatedAt,
      // No isDeleted — the row is never deleted; the security rules only check
      // userId.
    };

GamificationState gamificationFromRemote(Map<String, Object?> m) =>
    GamificationState(
      userId: _str(m['userId']),
      xp: _int(m['xp']),
      coins: _int(m['coins']),
      level: m['level'] == null ? 1 : _int(m['level']),
      currentStreak: _int(m['currentStreak']),
      longestStreak: _int(m['longestStreak']),
      lastActivityDate: _date(m['lastActivityDate']),
      unlockedBadgeIds: _stringList(m['unlockedBadgeIds']),
      transactionsLogged: _int(m['transactionsLogged']),
      budgetsCreated: _int(m['budgetsCreated']),
      budgetPeriodsWithinLimit: _int(m['budgetPeriodsWithinLimit']),
      scannedTransactionsLogged: _int(m['scannedTransactionsLogged']),
      recentEventIds: _stringList(m['recentEventIds']),
      updatedAt: _date(m['updatedAt']) ?? _epoch,
      syncStatus: SyncStatus.synced,
    );

// --- lenient coercion helpers ----------------------------------------

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String _str(Object? v) => v is String ? v : (v?.toString() ?? '');

String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _date(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  if (v is String) return DateTime.tryParse(v);
  // Firestore `Timestamp` is duck-typed here (has `.toDate()`) so this file
  // does not need to import cloud_firestore.
  try {
    final dynamic d = v;
    final result = d?.toDate();
    if (result is DateTime) return result;
  } catch (_) {
    // not a Timestamp
  }
  return null;
}

List<String> _stringList(Object? v) {
  if (v is List) {
    return v
        .whereType<Object>()
        .map((e) => e.toString())
        .toList(growable: false);
  }
  return const <String>[];
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final value in values) {
      if (value.name == name) return value;
    }
  }
  return fallback;
}

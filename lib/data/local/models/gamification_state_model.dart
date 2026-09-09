import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

part 'gamification_state_model.g.dart';

/// Hive persistence form of `domain/entities/GamificationState`. Stored as a
/// single entry keyed by [userId].
@HiveType(typeId: HiveTypeIds.gamificationState)
class GamificationStateModel {
  GamificationStateModel({
    required this.userId,
    required this.xp,
    required this.coins,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.unlockedBadgeIds,
    required this.updatedAt,
    required this.syncStatus,
    this.lastActivityDate,
    this.transactionsLogged = 0,
    this.budgetsCreated = 0,
    this.budgetPeriodsWithinLimit = 0,
    this.scannedTransactionsLogged = 0,
    this.recentEventIds = const <String>[],
  });

  @HiveField(0)
  String userId;

  @HiveField(1)
  int xp;

  @HiveField(2)
  int coins;

  @HiveField(3)
  int level;

  @HiveField(4)
  int currentStreak;

  @HiveField(5)
  int longestStreak;

  @HiveField(6)
  DateTime? lastActivityDate;

  @HiveField(7)
  List<String> unlockedBadgeIds;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  SyncStatus syncStatus;

  // --- Phase 8 additions (field numbers are permanent, never renumber) ---

  @HiveField(10)
  int transactionsLogged;

  @HiveField(11)
  int budgetsCreated;

  @HiveField(12)
  int budgetPeriodsWithinLimit;

  @HiveField(13)
  int scannedTransactionsLogged;

  @HiveField(14)
  List<String> recentEventIds;
}

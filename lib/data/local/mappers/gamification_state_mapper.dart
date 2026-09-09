import '../../../domain/entities/gamification_state.dart';
import '../models/gamification_state_model.dart';

extension GamificationStateModelMapper on GamificationStateModel {
  GamificationState toDomain() => GamificationState(
    userId: userId,
    xp: xp,
    coins: coins,
    level: level,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    lastActivityDate: lastActivityDate,
    unlockedBadgeIds: List<String>.unmodifiable(unlockedBadgeIds),
    transactionsLogged: transactionsLogged,
    budgetsCreated: budgetsCreated,
    budgetPeriodsWithinLimit: budgetPeriodsWithinLimit,
    scannedTransactionsLogged: scannedTransactionsLogged,
    recentEventIds: List<String>.unmodifiable(recentEventIds),
    updatedAt: updatedAt,
    syncStatus: syncStatus,
  );
}

extension GamificationStateEntityMapper on GamificationState {
  GamificationStateModel toModel() => GamificationStateModel(
    userId: userId,
    xp: xp,
    coins: coins,
    level: level,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    lastActivityDate: lastActivityDate,
    unlockedBadgeIds: List<String>.from(unlockedBadgeIds),
    transactionsLogged: transactionsLogged,
    budgetsCreated: budgetsCreated,
    budgetPeriodsWithinLimit: budgetPeriodsWithinLimit,
    scannedTransactionsLogged: scannedTransactionsLogged,
    recentEventIds: List<String>.from(recentEventIds),
    updatedAt: updatedAt,
    syncStatus: syncStatus,
  );
}

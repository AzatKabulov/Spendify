import 'dart:convert';

import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/gamification_state_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Produces a complete, human-readable JSON export of the user's own data
/// (Phase 10 — supports the PDPA data-access right). Derived caches
/// (`PeriodAggregate`) and regenerable AI output (`AdviceRecord`) are excluded
/// by design; soft-deleted records ARE included, marked `deleted: true`.
class DataExporter {
  DataExporter({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.gamification,
  });

  final TransactionRepository transactions;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final GamificationStateRepository gamification;

  Future<Map<String, Object?>> build({
    required DateTime generatedAt,
    String? account,
  }) async {
    final txns = await transactions.watchAllIncludingDeleted().first;
    final cats = await categories.watchAllIncludingDeleted().first;
    final buds = await budgets.watchAllIncludingDeleted().first;
    final game = await gamification.get();

    return <String, Object?>{
      'export': <String, Object?>{
        'app': 'Spendly',
        'formatVersion': 1,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'account': ?account,
        'note':
            'Amounts are in sen (1/100 MYR). Report caches and AI advice are '
            'not included — they are derived from the data below.',
      },
      'transactions': <Object?>[for (final t in txns) _transaction(t)],
      'categories': <Object?>[for (final c in cats) _category(c)],
      'budgets': <Object?>[for (final b in buds) _budget(b)],
      'gamification': game == null ? null : _gamificationJson(game),
      'counts': <String, Object?>{
        'transactions': txns.where((t) => !t.isDeleted).length,
        'categories': cats.where((c) => !c.isDeleted).length,
        'budgets': buds.where((b) => !b.isDeleted).length,
      },
    };
  }

  Future<String> buildJsonString({
    required DateTime generatedAt,
    String? account,
  }) async => const JsonEncoder.withIndent(
    '  ',
  ).convert(await build(generatedAt: generatedAt, account: account));

  static Map<String, Object?> _transaction(Transaction t) => <String, Object?>{
    'id': t.id,
    'amountMinor': t.amountMinor,
    'type': t.type.name,
    'categoryId': t.categoryId,
    'date': _ymd(t.date),
    'note': t.note,
    'source': t.source.name,
    'createdAt': t.createdAt.toUtc().toIso8601String(),
    'updatedAt': t.updatedAt.toUtc().toIso8601String(),
    if (t.isDeleted) 'deleted': true,
  };

  static Map<String, Object?> _category(Category c) => <String, Object?>{
    'id': c.id,
    'name': c.name,
    'iconCode': c.iconCode,
    'colorValue': c.colorValue,
    'isDefault': c.isDefault,
    'createdAt': c.createdAt.toUtc().toIso8601String(),
    'updatedAt': c.updatedAt.toUtc().toIso8601String(),
    if (c.isDeleted) 'deleted': true,
  };

  static Map<String, Object?> _budget(Budget b) => <String, Object?>{
    'id': b.id,
    'categoryId': b.categoryId,
    'limitAmountMinor': b.limitAmountMinor,
    'period': b.period.name,
    'startDate': _ymd(b.startDate),
    'createdAt': b.createdAt.toUtc().toIso8601String(),
    'updatedAt': b.updatedAt.toUtc().toIso8601String(),
    if (b.isDeleted) 'deleted': true,
  };

  static Map<String, Object?> _gamificationJson(GamificationState g) =>
      <String, Object?>{
        'xp': g.xp,
        'coins': g.coins,
        'level': g.level,
        'currentStreak': g.currentStreak,
        'longestStreak': g.longestStreak,
        'lastActivityDate': g.lastActivityDate == null
            ? null
            : _ymd(g.lastActivityDate!),
        'unlockedBadgeIds': g.unlockedBadgeIds,
        'transactionsLogged': g.transactionsLogged,
        'budgetsCreated': g.budgetsCreated,
        'budgetPeriodsWithinLimit': g.budgetPeriodsWithinLimit,
        'scannedTransactionsLogged': g.scannedTransactionsLogged,
        'updatedAt': g.updatedAt.toUtc().toIso8601String(),
      };

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

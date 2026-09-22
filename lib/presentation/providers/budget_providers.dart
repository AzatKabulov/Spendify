import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/patch.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/services/aggregation_service.dart';
import '../../domain/services/budget_evaluator.dart';
import '../../domain/services/gamification_event_sink.dart';
import 'auth_providers.dart';
import 'gamification_providers.dart';
import 'repository_providers.dart';
import 'transaction_providers.dart';

/// Live non-deleted budgets, overall first then by scope.
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchAll().map((list) {
    final sorted = [...list]
      ..sort((a, b) {
        if (a.isOverall != b.isOverall) return a.isOverall ? -1 : 1;
        return a.period.index.compareTo(b.period.index);
      });
    return sorted;
  });
});

/// The current-period expense aggregate id for a budget.
String _budgetAggregateId(String userId, Budget budget, DateTime now) {
  final periodType = budget.period == BudgetPeriod.weekly
      ? PeriodType.weekly
      : PeriodType.monthly;
  return PeriodAggregate.buildId(
    userId: userId,
    periodType: periodType,
    periodKey: periodKeyFor(now, periodType),
    categoryId: budget.categoryId,
  );
}

/// Evaluated status of every budget for the current period.
///
/// Phase 4: aggregate-backed. `spentMinor` is read straight from the cached
/// `PeriodAggregate` for the budget's `(period, category)` — no transaction
/// scan. The Monday-start ISO week / calendar-month boundaries are identical to
/// Phase 3's `BudgetEvaluator`, so the numbers match. Widgets are unchanged.
final budgetStatusesProvider = Provider<List<BudgetStatus>>((ref) {
  final uid = requireCurrentUserId(ref);
  final budgets = ref.watch(budgetsProvider).value ?? const [];
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final now = ref.watch(localTimeProvider)();
  final byId = {for (final a in aggregates) a.id: a};
  return [
    for (final b in budgets)
      budgetStatusFromSpent(
        budget: b,
        spentMinor:
            byId[_budgetAggregateId(uid, b, now)]?.totalExpenseMinor ?? 0,
        now: now,
      ),
  ];
});

/// Budget statuses that are `approaching` or `exceeded` — drives the home
/// warning banner.
final budgetWarningsProvider = Provider<List<BudgetStatus>>((ref) {
  return ref
      .watch(budgetStatusesProvider)
      .where((s) => s.needsAttention)
      .toList(growable: false);
});

/// Category ids whose category budget is currently `exceeded` — for the quiet
/// per-row indicator on the transaction list.
final overBudgetCategoryIdsProvider = Provider<Set<String>>((ref) {
  return {
    for (final s in ref.watch(budgetStatusesProvider))
      if (s.isExceeded && s.budget.categoryId != null) s.budget.categoryId!,
  };
});

/// Status for one specific budget id (budget list rows).
final budgetStatusByIdProvider = Provider.family<BudgetStatus?, String>((
  ref,
  budgetId,
) {
  for (final s in ref.watch(budgetStatusesProvider)) {
    if (s.budget.id == budgetId) return s;
  }
  return null;
});

/// Write actions for budgets.
final budgetActionsProvider = Provider<BudgetActions>((ref) {
  return BudgetActions(
    repository: ref.watch(budgetRepositoryProvider),
    gamificationSink: ref.watch(gamificationEventSinkProvider),
    userId: requireCurrentUserId(ref),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

class BudgetActions {
  BudgetActions({
    required BudgetRepository repository,
    required this.userId,
    required this.clock,
    required this.newId,
    GamificationEventSink? gamificationSink,
  }) : _repo = repository,
       _gamification = gamificationSink;

  final BudgetRepository _repo;

  /// Raises the "budget created" event. `null` disables gamification (tests).
  final GamificationEventSink? _gamification;

  /// The signed-in user new budgets are stamped with (Phase 5).
  final String userId;
  final Clock clock;
  final IdGenerator newId;

  Future<Budget> create({
    required String? categoryId,
    required int limitAmountMinor,
    required BudgetPeriod period,
    DateTime? startDate,
  }) async {
    final now = clock();
    final saved = await _repo.add(
      Budget.create(
        id: newId(),
        userId: userId,
        categoryId: categoryId,
        limitAmountMinor: limitAmountMinor,
        period: period,
        startDate: startDate ?? now,
        now: now,
      ),
    );
    _gamification?.budgetCreated(saved);
    return saved;
  }

  Future<Budget> edit(
    Budget original, {
    required String? categoryId,
    required int limitAmountMinor,
    required BudgetPeriod period,
    DateTime? startDate,
  }) {
    return _repo.update(
      original.copyWith(
        categoryId: patch(categoryId),
        limitAmountMinor: limitAmountMinor,
        period: period,
        startDate: startDate,
      ),
    );
  }

  Future<void> delete(String id) => _repo.delete(id);
}

/// True if a non-deleted budget already exists for this `(categoryId, period)`
/// pair (`categoryId == null` == overall). Used inline by the budget form.
bool isBudgetDuplicate(
  Iterable<Budget> existing,
  String? categoryId,
  BudgetPeriod period, {
  String? excludingId,
}) {
  return existing.any(
    (b) =>
        b.id != excludingId && b.categoryId == categoryId && b.period == period,
  );
}

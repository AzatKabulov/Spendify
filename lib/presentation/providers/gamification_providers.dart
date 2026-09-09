import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/budget.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/gamification_state_repository.dart';
import '../../domain/repositories/period_aggregate_repository.dart';
import '../../domain/services/aggregation_service.dart';
import '../../domain/services/budget_evaluator.dart';
import '../../domain/services/gamification_engine.dart';
import '../../domain/services/gamification_event_sink.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// The pure engine (CLAUDE.md §5). Const — it holds no state.
final gamificationEngineProvider = Provider<GamificationEngine>(
  (ref) => const GamificationEngine(),
);

/// Live gamification state for the signed-in user (level, coins, streak,
/// badges). Backed by the encrypted Hive row — works fully offline.
final gamificationStateProvider = StreamProvider<GamificationState>((ref) {
  return ref.watch(gamificationStateRepositoryProvider).watch();
});

/// The sink the Transaction / Budget action layers push events into. Same
/// object as [gamificationRunnerProvider]; separate provider so callers depend
/// on the narrow interface, not the implementation.
///
/// Only valid behind `AuthGate` (it resolves uid-scoped repositories). The
/// action providers that read it are themselves auth-gated.
final gamificationEventSinkProvider = Provider<GamificationEventSink>(
  (ref) => ref.watch(gamificationRunnerProvider),
);

/// The runner: receives events, runs the pure engine against the current state,
/// persists any change, and posts a [GamificationResult] for the feedback UI.
final gamificationRunnerProvider = Provider<GamificationRunner>((ref) {
  return GamificationRunner(
    stateRepo: ref.watch(gamificationStateRepositoryProvider),
    engine: ref.watch(gamificationEngineProvider),
    categories: ref.watch(categoryRepositoryProvider),
    aggregates: ref.watch(periodAggregateRepositoryProvider),
    localNow: ref.watch(localTimeProvider),
    onFeedback: (result) =>
        ref.read(gamificationFeedbackProvider.notifier).post(result),
  );
});

/// Holds the most recent reward worth surfacing to the user. The feedback
/// listener consumes and clears it. A burst (e.g. the launch reconciler
/// completing several budget periods) keeps only the latest — the stats screen
/// shows the full picture.
final gamificationFeedbackProvider =
    NotifierProvider<GamificationFeedbackController, GamificationResult?>(
      GamificationFeedbackController.new,
    );

class GamificationFeedbackController extends Notifier<GamificationResult?> {
  @override
  GamificationResult? build() => null;

  void post(GamificationResult result) => state = result;

  /// Returns the pending result (if any) and clears it.
  GamificationResult? consume() {
    final pending = state;
    state = null;
    return pending;
  }
}

/// Serialises gamification processing off the critical path. Events are applied
/// one at a time (read state → run engine → save), so concurrent logs can't
/// race on the single per-user row.
class GamificationRunner implements GamificationEventSink {
  GamificationRunner({
    required this.stateRepo,
    required this.engine,
    required this.categories,
    required this.aggregates,
    required this.localNow,
    required this.onFeedback,
  });

  final GamificationStateRepository stateRepo;
  final GamificationEngine engine;
  final CategoryRepository categories;
  final PeriodAggregateRepository aggregates;
  final DateTime Function() localNow;
  final void Function(GamificationResult) onFeedback;

  /// The processing queue tail. Each event chains onto the previous one.
  Future<void> _tail = Future<void>.value();

  /// Test hook: completes when everything enqueued so far has been processed.
  @visibleForTesting
  Future<void> get whenIdle => _tail;

  @override
  void transactionLogged(Transaction txn) {
    _enqueue(
      TransactionLogged(
        transactionId: txn.id,
        source: txn.source,
        loggedAt: localNow(),
      ),
      surfaceFeedback: true,
    );
  }

  @override
  void transactionDeleted(Transaction txn) {
    // A reversal is not a "reward moment" — apply it, but don't toast.
    _enqueue(
      TransactionDeleted(transactionId: txn.id, deletedAt: localNow()),
      surfaceFeedback: false,
    );
  }

  @override
  void budgetCreated(Budget budget) {
    _enqueue(
      BudgetCreated(budgetId: budget.id, createdAt: localNow()),
      surfaceFeedback: true,
    );
  }

  @override
  void budgetPeriodCompleted({
    required String budgetId,
    required String periodKey,
    required BudgetPeriod period,
    required bool stayedWithinLimit,
  }) {
    _enqueue(
      BudgetPeriodCompleted(
        budgetId: budgetId,
        periodKey: periodKey,
        period: period,
        stayedWithinLimit: stayedWithinLimit,
        completedAt: localNow(),
      ),
      surfaceFeedback: true,
    );
  }

  void _enqueue(GamificationEvent event, {required bool surfaceFeedback}) {
    _tail = _tail
        .then((_) => _apply(event, surfaceFeedback: surfaceFeedback))
        .catchError((Object error, StackTrace stack) {
          // Gamification must never break the write that triggered it.
          if (!kReleaseMode) {
            debugPrint('GAMIFICATION: ${event.id} failed: $error\n$stack');
          }
        });
  }

  Future<void> _apply(
    GamificationEvent event, {
    required bool surfaceFeedback,
  }) async {
    final before = await stateRepo.getOrCreate();

    final resolved = await _resolveAllCategories(event, before);
    final result = engine.process(resolved, before);

    if (result.state != before) {
      await stateRepo.save(result.state);
    }
    if (surfaceFeedback && (result.hasVisibleReward || result.leveledUp)) {
      onFeedback(result);
    }
  }

  /// The `all_categories` badge needs a listener-computed flag. Only bother
  /// while the badge is still locked, and derive "used" from the cheap cached
  /// per-category yearly aggregates rather than scanning the transaction table.
  Future<GamificationEvent> _resolveAllCategories(
    GamificationEvent event,
    GamificationState before,
  ) async {
    if (event is! TransactionLogged) return event;
    if (before.unlockedBadgeIds.contains('all_categories')) return event;

    final allCategories = await categories.getAll();
    if (allCategories.isEmpty) return event;

    final yearly = await aggregates.getByPeriodType(PeriodType.yearly);
    final usedCategoryIds = <String>{
      for (final a in yearly)
        if (a.categoryId != null && a.transactionCount > 0) a.categoryId!,
    };
    final allUsed = allCategories.every((c) => usedCategoryIds.contains(c.id));
    if (!allUsed) return event;

    return TransactionLogged(
      transactionId: event.transactionId,
      source: event.source,
      loggedAt: event.occurredAt,
      allCategoriesUsed: true,
    );
  }
}

/// Raises [BudgetPeriodCompleted] for periods that ended while the app was
/// closed. Runs on launch and on resume (never on the add-transaction path).
///
/// Only the **single most recently ended** period per budget is checked per
/// run — a user away for months has just last period evaluated, not every
/// missed one (documented limitation). The engine dedupes on
/// `(budgetId, periodKey)`, and this pre-checks the same key against the
/// current `recentEventIds` window to avoid redundant enqueues.
final gamificationReconcilerProvider = Provider<GamificationReconciler>(
  GamificationReconciler.new,
);

class GamificationReconciler {
  GamificationReconciler(this._ref);

  final Ref _ref;

  Future<void> runIfSignedIn() async {
    if (_ref.read(currentUserIdProvider) == null) return;
    try {
      await _run();
    } catch (error, stack) {
      if (!kReleaseMode) {
        debugPrint('GAMIFICATION reconciler failed: $error\n$stack');
      }
    }
  }

  Future<void> _run() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) return;

    final budgets = await _ref.read(budgetRepositoryProvider).getAll();
    if (budgets.isEmpty) return;

    final now = _ref.read(localTimeProvider)();
    final aggregateRepo = _ref.read(periodAggregateRepositoryProvider);
    final sink = _ref.read(gamificationEventSinkProvider);
    final state = await _ref.read(gamificationStateRepositoryProvider).get();
    final seenEventIds = state?.recentEventIds ?? const <String>[];

    for (final budget in budgets) {
      final period = lastCompletedBudgetPeriod(budget, now);
      if (period == null) continue;

      if (seenEventIds.contains('bp:${budget.id}:${period.key}')) continue;

      final aggregate = await aggregateRepo.getById(
        PeriodAggregate.buildId(
          userId: uid,
          periodType: period.type,
          periodKey: period.key,
          categoryId: budget.categoryId,
        ),
      );
      final spent = aggregate?.totalExpenseMinor ?? 0;

      sink.budgetPeriodCompleted(
        budgetId: budget.id,
        periodKey: period.key,
        period: budget.period,
        stayedWithinLimit: spent <= budget.limitAmountMinor,
      );
    }
  }
}

/// The most recently ended period for [budget] as of [now], or `null` if the
/// budget did not exist for the whole of it. Pure — exposed for unit tests.
({PeriodType type, String key})? lastCompletedBudgetPeriod(
  Budget budget,
  DateTime now,
) {
  final type = budget.period == BudgetPeriod.weekly
      ? PeriodType.weekly
      : PeriodType.monthly;
  final (currentStart, _) = budgetPeriodWindow(budget.period, now);
  final prevAnchor = shiftPeriod(type, currentStart, -1);
  final key = periodKeyFor(prevAnchor, type);
  final prevBounds = periodBounds(type, key);

  final startDay = DateTime(
    budget.startDate.year,
    budget.startDate.month,
    budget.startDate.day,
  );
  if (startDay.isAfter(prevBounds.start)) return null;

  return (type: type, key: key);
}

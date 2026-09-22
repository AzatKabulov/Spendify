import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/advice_item.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/aggregation_service.dart';
import '../../domain/services/budget_evaluator.dart';
import 'advice_providers.dart';
import 'budget_providers.dart';
import 'repository_providers.dart';
import 'report_providers.dart';
import 'transaction_providers.dart';

/// This calendar month at a glance, read from the cached `PeriodAggregate`s
/// only (CLAUDE.md §6 — no transaction scan): totals, the running net for each
/// day so far (the balance-card sparkline), and the biggest spending
/// categories.
class HomeMonth {
  const HomeMonth({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.cumulativeNetMinor,
    required this.topCategories,
  });

  final int incomeMinor;
  final int expenseMinor;

  /// Running (income − expense) at the end of each day 1..today.
  final List<int> cumulativeNetMinor;

  /// Up to four categories by expense, largest first.
  final List<CategorySlice> topCategories;

  int get netMinor => incomeMinor - expenseMinor;
  bool get isEmpty => incomeMinor == 0 && expenseMinor == 0;
}

final homeMonthProvider = Provider<HomeMonth>((ref) {
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
  final now = ref.watch(localTimeProvider)();
  final monthKey = periodKeyFor(now, PeriodType.monthly);

  var income = 0;
  var expense = 0;
  final categories = <CategorySlice>[];
  final byDay = <String, int>{};

  for (final a in aggregates) {
    if (a.periodType == PeriodType.daily && a.categoryId == null) {
      byDay[a.periodKey] = a.totalIncomeMinor - a.totalExpenseMinor;
    }
    if (a.periodType != PeriodType.monthly || a.periodKey != monthKey) continue;
    if (a.categoryId == null) {
      income = a.totalIncomeMinor;
      expense = a.totalExpenseMinor;
    }
  }
  for (final a in aggregates) {
    if (a.periodType == PeriodType.monthly &&
        a.periodKey == monthKey &&
        a.categoryId != null &&
        a.totalExpenseMinor > 0) {
      categories.add(
        CategorySlice(
          categoryId: a.categoryId!,
          expenseMinor: a.totalExpenseMinor,
          fractionOfExpense: expense == 0 ? 0 : a.totalExpenseMinor / expense,
        ),
      );
    }
  }
  categories.sort((x, y) => y.expenseMinor.compareTo(x.expenseMinor));

  final running = <int>[];
  var total = 0;
  for (var d = 1; d <= now.day; d++) {
    total +=
        byDay[periodKeyFor(
          DateTime(now.year, now.month, d),
          PeriodType.daily,
        )] ??
        0;
    running.add(total);
  }

  return HomeMonth(
    incomeMinor: income,
    expenseMinor: expense,
    cumulativeNetMinor: running,
    topCategories: categories.take(4).toList(growable: false),
  );
});

/// The overall monthly budget's live status, or `null` if none is set.
final overallMonthlyBudgetProvider = Provider<BudgetStatus?>((ref) {
  for (final s in ref.watch(budgetStatusesProvider)) {
    if (s.budget.isOverall && s.budget.period == BudgetPeriod.monthly) return s;
  }
  return null;
});

/// Whether the balance figure is masked (the eye toggle). Lives only in
/// memory — it resets every launch so a hidden balance is never a surprise.
class BalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final balanceHiddenProvider = NotifierProvider<BalanceHiddenNotifier, bool>(
  BalanceHiddenNotifier.new,
);

/// The first tip from the last advice the user already has cached on the
/// device. Never triggers a Gemini call — the home card only shows what the
/// Insights screen has already generated (CLAUDE.md §7: no surprise
/// transmissions).
final latestAdviceTipProvider = FutureProvider.autoDispose<AdviceItem?>((
  ref,
) async {
  final cached = await ref.watch(cachedAdviceProvider.future);
  if (cached == null || cached.items.isEmpty) return null;
  return cached.items.first;
});

/// Advice already generated and cached on the device, with when it was made.
/// Never triggers a Gemini call — the Trends screen and the home card only
/// show what the Insights screen has already produced (CLAUDE.md §7: no
/// surprise transmissions).
class CachedAdvice {
  const CachedAdvice({required this.items, required this.generatedAt});

  final List<AdviceItem> items;
  final DateTime generatedAt;
}

final cachedAdviceProvider = FutureProvider.autoDispose<CachedAdvice?>((
  ref,
) async {
  if (!ref.watch(adviceConfiguredProvider)) return null;
  final record = await ref.watch(adviceRecordRepositoryProvider).getLatest();
  if (record == null || record.adviceItems.isEmpty) return null;
  return CachedAdvice(
    items: record.adviceItems,
    generatedAt: record.generatedAt,
  );
});

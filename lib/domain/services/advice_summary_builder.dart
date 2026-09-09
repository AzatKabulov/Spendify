/// Builds the **aggregated** spending summary that is sent to Gemini for advice
/// (Phase 9). PURE — no storage, no UI, `now` injected.
///
/// **Ethics (CLAUDE.md §7 — [REPORT COMMITMENT]):** this is the concrete
/// expression of "only aggregated data goes to Gemini". The summary is built
/// entirely from `PeriodAggregate` totals + `Budget` limits + category *labels*.
/// It contains **no** individual transaction rows, merchant names, notes,
/// purchase dates, amounts-to-the-sen, user id or email. Money is rounded to
/// whole ringgit and percentages to whole numbers so the payload cannot be
/// reverse-engineered into individual purchases. Category names are included
/// (the advice must "reference the user's real categories") — the Phase 10
/// transparency screen shows the user exactly this object via [AdviceSummary.toJson].
library;

import '../entities/budget.dart';
import '../entities/category.dart';
import '../entities/enums.dart';
import '../entities/period_aggregate.dart';
import 'aggregation_service.dart';
import 'budget_evaluator.dart';

/// How many spending categories to name in the summary.
const int kAdviceTopCategoryCount = 6;

class AdviceSummary {
  const AdviceSummary({
    required this.periodLabel,
    required this.currency,
    required this.incomeRm,
    required this.expenseRm,
    required this.netRm,
    required this.topCategories,
    required this.trends,
    required this.budgetAdherence,
    required this.daysLogged,
    required this.daysInPeriod,
    required this.transactionCount,
  });

  /// Human label for the period, e.g. "September 2026".
  final String periodLabel;
  final String currency;

  /// Whole ringgit, rounded.
  final int incomeRm;
  final int expenseRm;
  final int netRm;

  final List<AdviceCategoryLine> topCategories;
  final List<AdviceTrendLine> trends;
  final List<AdviceBudgetLine> budgetAdherence;

  /// Distinct calendar days in the period with at least one logged transaction,
  /// and how many days of the period have elapsed — the consistency signal.
  final int daysLogged;
  final int daysInPeriod;

  /// Transactions counted in the period (informational for the model).
  final int transactionCount;

  /// The payload sent to Gemini, and (Phase 10) what the transparency screen
  /// shows the user. Deterministic key order.
  ///
  /// [stableOnly] drops the fields that drift with the clock rather than with
  /// spending ([daysInPeriod], [transactionCount]) — the caching hash is taken
  /// over `toJson(stableOnly: true)` so a day merely passing does not force a
  /// regenerate. `daysLogged` stays because it only moves when the user logs
  /// (which also moves the totals).
  Map<String, Object?> toJson({bool stableOnly = false}) => <String, Object?>{
    'period': periodLabel,
    'currency': currency,
    'totals': <String, Object?>{
      'income': incomeRm,
      'expense': expenseRm,
      'net': netRm,
    },
    'topCategories': <Object?>[
      for (final c in topCategories)
        <String, Object?>{
          'category': c.category,
          'spent': c.spentRm,
          'shareOfExpensePercent': c.shareOfExpensePct,
        },
    ],
    'trendsVsPreviousPeriod': <Object?>[
      for (final t in trends)
        <String, Object?>{
          'category': t.category,
          'direction': t.direction,
          if (t.changePercent != null) 'changePercent': t.changePercent,
        },
    ],
    'budgets': <Object?>[
      for (final b in budgetAdherence)
        <String, Object?>{
          'scope': b.scope,
          'limit': b.limitRm,
          'spent': b.spentRm,
          'status': b.exceeded ? 'exceeded' : 'within',
          if (b.exceeded) 'overByPercent': b.overByPercent,
        },
    ],
    'loggingConsistency': <String, Object?>{
      'daysLogged': daysLogged,
      if (!stableOnly) 'daysInPeriod': daysInPeriod,
    },
    if (!stableOnly) 'transactionCount': transactionCount,
  };
}

class AdviceCategoryLine {
  const AdviceCategoryLine({
    required this.category,
    required this.spentRm,
    required this.shareOfExpensePct,
  });
  final String category;
  final int spentRm;
  final int shareOfExpensePct;
}

class AdviceTrendLine {
  const AdviceTrendLine({
    required this.category,
    required this.direction,
    this.changePercent,
  });

  /// "up", "down", "flat", or "new" (no spend in the previous period).
  final String category;
  final String direction;
  final int? changePercent;
}

class AdviceBudgetLine {
  const AdviceBudgetLine({
    required this.scope,
    required this.limitRm,
    required this.spentRm,
    required this.exceeded,
    this.overByPercent = 0,
  });

  /// "Overall" or a category name.
  final String scope;
  final int limitRm;
  final int spentRm;
  final bool exceeded;
  final int overByPercent;
}

// --- builder ---------------------------------------------------------

int _rm(int minor) => (minor / 100).round();
int _pct(num fraction) => (fraction * 100).round();

/// Rounds a percent change to the nearest 5, so it stays coarse.
int _coarsePct(num p) => (p / 5).round() * 5;

AdviceSummary buildAdviceSummary({
  required List<PeriodAggregate> aggregates,
  required List<Budget> budgets,
  required List<Category> categories,
  required DateTime now,
  PeriodType periodType = PeriodType.monthly,
}) {
  final names = <String, String>{for (final c in categories) c.id: c.name};
  String nameOf(String? id) =>
      id == null ? 'Overall' : (names[id] ?? 'Uncategorised');

  final currentKey = periodKeyFor(now, periodType);
  final previousKey = periodKeyFor(
    shiftPeriod(periodType, now, -1),
    periodType,
  );
  final bounds = periodBounds(periodType, currentKey);

  PeriodAggregate? totalFor(String key) => _find(
    aggregates,
    periodType: periodType,
    periodKey: key,
    categoryId: null,
  );
  List<PeriodAggregate> categoryAggsFor(String key) => aggregates
      .where(
        (a) =>
            a.periodType == periodType &&
            a.periodKey == key &&
            a.categoryId != null,
      )
      .toList(growable: false);

  final currentTotal = totalFor(currentKey);
  final currentByCategory = categoryAggsFor(currentKey);
  final previousByCategory = <String, int>{
    for (final a in categoryAggsFor(previousKey))
      a.categoryId!: a.totalExpenseMinor,
  };

  final expenseMinor = currentTotal?.totalExpenseMinor ?? 0;
  final incomeMinor = currentTotal?.totalIncomeMinor ?? 0;

  // Top categories by expense.
  final ranked =
      currentByCategory.where((a) => a.totalExpenseMinor > 0).toList()
        ..sort((x, y) => y.totalExpenseMinor.compareTo(x.totalExpenseMinor));
  final top = ranked.take(kAdviceTopCategoryCount).toList(growable: false);

  final topCategories = <AdviceCategoryLine>[
    for (final a in top)
      AdviceCategoryLine(
        category: nameOf(a.categoryId),
        spentRm: _rm(a.totalExpenseMinor),
        shareOfExpensePct: expenseMinor == 0
            ? 0
            : _pct(a.totalExpenseMinor / expenseMinor),
      ),
  ];

  final trends = <AdviceTrendLine>[
    for (final a in top)
      _trend(
        category: nameOf(a.categoryId),
        currentMinor: a.totalExpenseMinor,
        previousMinor: previousByCategory[a.categoryId!] ?? 0,
      ),
  ];

  // Budget adherence — each budget over its OWN current period.
  final budgetAdherence = <AdviceBudgetLine>[
    for (final b in budgets.where((b) => !b.isDeleted))
      _budgetLine(b, aggregates, now, nameOf(b.categoryId)),
  ];

  // Consistency: distinct days in the window with a logged transaction.
  final daysLogged = aggregates
      .where(
        (a) =>
            a.periodType == PeriodType.daily &&
            a.categoryId == null &&
            a.transactionCount > 0 &&
            _within(a.periodKey, bounds),
      )
      .length;
  final daysInPeriod = _elapsedDays(bounds, now);

  final incomeRm = _rm(incomeMinor);
  final expenseRm = _rm(expenseMinor);
  return AdviceSummary(
    periodLabel: _periodLabel(periodType, currentKey),
    currency: 'MYR',
    incomeRm: incomeRm,
    expenseRm: expenseRm,
    netRm: incomeRm - expenseRm,
    topCategories: topCategories,
    trends: trends,
    budgetAdherence: budgetAdherence,
    daysLogged: daysLogged,
    daysInPeriod: daysInPeriod,
    transactionCount: currentTotal?.transactionCount ?? 0,
  );
}

PeriodAggregate? _find(
  List<PeriodAggregate> aggregates, {
  required PeriodType periodType,
  required String periodKey,
  required String? categoryId,
}) {
  for (final a in aggregates) {
    if (a.periodType == periodType &&
        a.periodKey == periodKey &&
        a.categoryId == categoryId) {
      return a;
    }
  }
  return null;
}

AdviceTrendLine _trend({
  required String category,
  required int currentMinor,
  required int previousMinor,
}) {
  if (previousMinor == 0) {
    return AdviceTrendLine(category: category, direction: 'new');
  }
  final changePct = (currentMinor - previousMinor) / previousMinor * 100;
  if (changePct > 10) {
    return AdviceTrendLine(
      category: category,
      direction: 'up',
      changePercent: _coarsePct(changePct),
    );
  }
  if (changePct < -10) {
    return AdviceTrendLine(
      category: category,
      direction: 'down',
      changePercent: _coarsePct(changePct),
    );
  }
  return AdviceTrendLine(category: category, direction: 'flat');
}

AdviceBudgetLine _budgetLine(
  Budget budget,
  List<PeriodAggregate> aggregates,
  DateTime now,
  String scope,
) {
  final periodType = budget.period == BudgetPeriod.weekly
      ? PeriodType.weekly
      : PeriodType.monthly;
  final key = periodKeyFor(now, periodType);
  final spentMinor =
      _find(
        aggregates,
        periodType: periodType,
        periodKey: key,
        categoryId: budget.categoryId,
      )?.totalExpenseMinor ??
      0;

  final status = budgetStatusFromSpent(
    budget: budget,
    spentMinor: spentMinor,
    now: now,
  );
  final over = status.isExceeded && budget.limitAmountMinor > 0
      ? _coarsePct(
          (spentMinor - budget.limitAmountMinor) /
              budget.limitAmountMinor *
              100,
        )
      : 0;

  return AdviceBudgetLine(
    scope: scope,
    limitRm: _rm(budget.limitAmountMinor),
    spentRm: _rm(spentMinor),
    exceeded: status.isExceeded,
    overByPercent: over,
  );
}

bool _within(String dayKey, ({DateTime start, DateTime end}) bounds) {
  final d = DateTime.tryParse(dayKey);
  if (d == null) return false;
  return !d.isBefore(bounds.start) && d.isBefore(bounds.end);
}

int _elapsedDays(({DateTime start, DateTime end}) bounds, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final end = today.isBefore(bounds.end) ? today : bounds.end;
  final days = end.difference(bounds.start).inDays + 1;
  final full = bounds.end.difference(bounds.start).inDays;
  return days.clamp(1, full);
}

String _periodLabel(PeriodType type, String key) {
  switch (type) {
    case PeriodType.monthly:
      final parts = key.split('-');
      return '${_month(int.parse(parts[1]))} ${parts[0]}';
    case PeriodType.yearly:
      return key;
    case PeriodType.weekly:
      final parts = key.split('-W');
      return 'week ${parts[1]}, ${parts[0]}';
    case PeriodType.daily:
      return key;
  }
}

String _month(int m) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][m - 1];

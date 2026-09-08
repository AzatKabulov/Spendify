import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/services/aggregation_service.dart';
import 'repository_providers.dart';
import 'transaction_providers.dart';

/// Which period the reports screen is showing.
class ReportSelection {
  const ReportSelection(this.type, this.anchor);

  final PeriodType type;

  /// A date-only value that lands inside the viewed period.
  final DateTime anchor;

  String get periodKey => periodKeyFor(anchor, type);
  ({DateTime start, DateTime end}) get bounds => periodBounds(type, periodKey);

  ReportSelection copyWith({PeriodType? type, DateTime? anchor}) =>
      ReportSelection(type ?? this.type, anchor ?? this.anchor);
}

class ReportSelectionNotifier extends Notifier<ReportSelection> {
  @override
  ReportSelection build() {
    final now = ref.watch(localTimeProvider)();
    return ReportSelection(
      PeriodType.monthly,
      DateTime(now.year, now.month, now.day),
    );
  }

  DateTime get _today {
    final now = ref.read(localTimeProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// `true` unless the current view is already the period containing today.
  bool get canGoNext => !state.bounds.end.isAfter(_today);

  void setType(PeriodType type) => state = state.copyWith(type: type);

  void previous() =>
      state = state.copyWith(anchor: shiftPeriod(state.type, state.anchor, -1));

  void next() {
    if (canGoNext) {
      state = state.copyWith(anchor: shiftPeriod(state.type, state.anchor, 1));
    }
  }

  void jumpToNow() => state = ReportSelection(state.type, _today);
}

final reportSelectionProvider =
    NotifierProvider<ReportSelectionNotifier, ReportSelection>(
      ReportSelectionNotifier.new,
    );

/// One category's share of expense for the viewed period.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.expenseMinor,
    required this.fractionOfExpense,
  });

  final String categoryId;
  final int expenseMinor;
  final double fractionOfExpense;
}

/// Everything the report header + pie + breakdown list need — **all from the
/// cached `PeriodAggregate`s**, no transaction scan (CLAUDE.md §6).
class ReportData {
  const ReportData({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transactionCount,
    required this.byCategory,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int transactionCount;

  /// Categories with expense this period, largest first.
  final List<CategorySlice> byCategory;

  int get netMinor => incomeMinor - expenseMinor;
  bool get isEmpty => transactionCount == 0;

  static const ReportData empty = ReportData(
    incomeMinor: 0,
    expenseMinor: 0,
    transactionCount: 0,
    byCategory: <CategorySlice>[],
  );
}

/// Report figures for the current [reportSelectionProvider], from the cache.
final reportDataProvider = Provider<ReportData>((ref) {
  final selection = ref.watch(reportSelectionProvider);
  final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];

  final forPeriod = aggregates.where(
    (a) => a.periodType == selection.type && a.periodKey == selection.periodKey,
  );
  PeriodAggregate? total;
  final categoryAggs = <PeriodAggregate>[];
  for (final a in forPeriod) {
    if (a.categoryId == null) {
      total = a;
    } else {
      categoryAggs.add(a);
    }
  }
  if (total == null) return ReportData.empty;

  final totalExpense = total.totalExpenseMinor;
  final slices = categoryAggs.where((a) => a.totalExpenseMinor > 0).map((a) {
    return CategorySlice(
      categoryId: a.categoryId!,
      expenseMinor: a.totalExpenseMinor,
      fractionOfExpense: totalExpense == 0
          ? 0
          : a.totalExpenseMinor / totalExpense,
    );
  }).toList()..sort((x, y) => y.expenseMinor.compareTo(x.expenseMinor));

  return ReportData(
    incomeMinor: total.totalIncomeMinor,
    expenseMinor: total.totalExpenseMinor,
    transactionCount: total.transactionCount,
    byCategory: slices,
  );
});

/// One bar of the "spend over time" chart.
class SpendBar {
  const SpendBar({required this.label, required this.expenseMinor});

  final String label;
  final int expenseMinor;
}

/// Bars for the "spend over time" chart:
///  - yearly  -> 12 months, read from the monthly period-total aggregates;
///  - weekly  -> 7 days, weekly/monthly bucket the **viewed period's**
///    transactions only (a bounded slice, never the whole history).
///  - monthly -> one bar per day of the month.
final spendOverTimeProvider = Provider<List<SpendBar>>((ref) {
  final selection = ref.watch(reportSelectionProvider);

  if (selection.type == PeriodType.yearly) {
    final aggregates = ref.watch(periodAggregatesProvider).value ?? const [];
    final year = int.parse(selection.periodKey);
    final byMonth = <String, int>{
      for (final a in aggregates)
        if (a.periodType == PeriodType.monthly && a.categoryId == null)
          a.periodKey: a.totalExpenseMinor,
    };
    return [
      for (var m = 1; m <= 12; m++)
        SpendBar(
          label: _monthAbbr(m),
          expenseMinor: byMonth['$year-${m.toString().padLeft(2, '0')}'] ?? 0,
        ),
    ];
  }

  // weekly / monthly: bucket the period's transactions by day.
  final bounds = selection.bounds;
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final inPeriod = transactions.where(
    (t) =>
        !t.isDeleted &&
        t.type == TransactionType.expense &&
        !t.date.isBefore(bounds.start) &&
        t.date.isBefore(bounds.end),
  );
  final perDay = <int, int>{}; // day-offset from start -> expense
  for (final t in inPeriod) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    final offset = day.difference(bounds.start).inDays;
    perDay[offset] = (perDay[offset] ?? 0) + t.amountMinor;
  }
  final dayCount = bounds.end.difference(bounds.start).inDays;
  return [
    for (var i = 0; i < dayCount; i++)
      SpendBar(
        label: '${bounds.start.add(Duration(days: i)).day}',
        expenseMinor: perDay[i] ?? 0,
      ),
  ];
});

String _monthAbbr(int m) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];

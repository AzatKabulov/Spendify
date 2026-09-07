import 'enums.dart';

/// A pre-rolled per-period total, used so report screens never scan the whole
/// transaction history (CLAUDE.md §6 — this is a [REPORT COMMITMENT], not an
/// optimisation). **Local cache only**: rebuilt from transactions, never synced.
///
/// Phase 1 defines and persists it; the logic that keeps it in step with
/// transaction changes is Phase 4.
class PeriodAggregate {
  const PeriodAggregate({
    required this.id,
    required this.userId,
    required this.periodType,
    required this.periodKey,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.transactionCount,
    required this.updatedAt,
    this.categoryId,
  });

  /// Sentinel used in the composite id when [categoryId] is null (the
  /// "all categories" aggregate for a period).
  static const String allCategoriesToken = 'all';

  /// Composite key: `userId_periodType_periodKey_categoryId`.
  static String buildId({
    required String userId,
    required PeriodType periodType,
    required String periodKey,
    String? categoryId,
  }) =>
      '${userId}_${periodType.name}_${periodKey}_${categoryId ?? allCategoriesToken}';

  final String id;
  final String userId;
  final PeriodType periodType;

  /// e.g. `2026-09` (monthly), `2026-W36` (weekly), `2026` (yearly).
  final String periodKey;

  /// `null` = aggregate across all categories for this period.
  final String? categoryId;

  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int transactionCount;
  final DateTime updatedAt;

  int get netMinor => totalIncomeMinor - totalExpenseMinor;

  PeriodAggregate copyWith({
    int? totalIncomeMinor,
    int? totalExpenseMinor,
    int? transactionCount,
    DateTime? updatedAt,
  }) {
    return PeriodAggregate(
      id: id,
      userId: userId,
      periodType: periodType,
      periodKey: periodKey,
      categoryId: categoryId,
      totalIncomeMinor: totalIncomeMinor ?? this.totalIncomeMinor,
      totalExpenseMinor: totalExpenseMinor ?? this.totalExpenseMinor,
      transactionCount: transactionCount ?? this.transactionCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodAggregate &&
      other.id == id &&
      other.userId == userId &&
      other.periodType == periodType &&
      other.periodKey == periodKey &&
      other.categoryId == categoryId &&
      other.totalIncomeMinor == totalIncomeMinor &&
      other.totalExpenseMinor == totalExpenseMinor &&
      other.transactionCount == transactionCount &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    periodType,
    periodKey,
    categoryId,
    totalIncomeMinor,
    totalExpenseMinor,
    transactionCount,
    updatedAt,
  );

  @override
  String toString() =>
      'PeriodAggregate($id, in=$totalIncomeMinor, out=$totalExpenseMinor, '
      'n=$transactionCount)';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/domain/services/aggregation_service.dart';

Transaction txn(
  DateTime date, {
  required TransactionType type,
  int amountMinor = 1000,
  String categoryId = 'food',
  bool isDeleted = false,
}) => Transaction(
  id: '${date.toIso8601String()}-$categoryId-$amountMinor-$isDeleted',
  userId: 'u',
  amountMinor: amountMinor,
  type: type,
  categoryId: categoryId,
  date: date,
  source: TransactionSource.manual,
  createdAt: date,
  updatedAt: date,
  isDeleted: isDeleted,
);

void main() {
  final now = DateTime(2026, 9, 8);

  group('periodKeyFor', () {
    test('monthly / yearly', () {
      expect(
        periodKeyFor(DateTime(2026, 9, 15), PeriodType.monthly),
        '2026-09',
      );
      expect(periodKeyFor(DateTime(2026, 1, 1), PeriodType.monthly), '2026-01');
      expect(periodKeyFor(DateTime(2026, 12, 31), PeriodType.yearly), '2026');
    });

    test('weekly (ISO week) — normal dates', () {
      // 2026-09-08 is a Tuesday, ISO week 37.
      expect(periodKeyFor(DateTime(2026, 9, 8), PeriodType.weekly), '2026-W37');
      // Monday 2026-09-14 -> week 38.
      expect(
        periodKeyFor(DateTime(2026, 9, 14), PeriodType.weekly),
        '2026-W38',
      );
      // Sunday 2026-09-13 is still week 37.
      expect(
        periodKeyFor(DateTime(2026, 9, 13), PeriodType.weekly),
        '2026-W37',
      );
    });

    test('ISO week edge: 29 Dec 2025 belongs to 2026-W01', () {
      expect(
        periodKeyFor(DateTime(2025, 12, 29), PeriodType.weekly),
        '2026-W01',
      );
      expect(periodKeyFor(DateTime(2026, 1, 1), PeriodType.weekly), '2026-W01');
      expect(
        periodKeyFor(DateTime(2025, 12, 28), PeriodType.weekly),
        '2025-W52',
      );
    });

    test('ISO week edge: 1 Jan 2027 belongs to 2026-W53 (a 53-week year)', () {
      expect(periodKeyFor(DateTime(2027, 1, 1), PeriodType.weekly), '2026-W53');
      expect(periodKeyFor(DateTime(2027, 1, 3), PeriodType.weekly), '2026-W53');
      expect(periodKeyFor(DateTime(2027, 1, 4), PeriodType.weekly), '2027-W01');
    });

    test(
      'ISO week edge: 2024 is a leap year, its W01 starts 2024-01-01 (Mon)',
      () {
        expect(
          periodKeyFor(DateTime(2024, 1, 1), PeriodType.weekly),
          '2024-W01',
        );
        expect(
          periodKeyFor(DateTime(2023, 12, 31), PeriodType.weekly),
          '2023-W52',
        );
      },
    );
  });

  group('periodBounds', () {
    test('monthly — 30/31-day and February leap/non-leap', () {
      expect(periodBounds(PeriodType.monthly, '2026-04'), (
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 5, 1),
      ));
      expect(periodBounds(PeriodType.monthly, '2026-12'), (
        start: DateTime(2026, 12, 1),
        end: DateTime(2027, 1, 1),
      ));
      expect(
        periodBounds(PeriodType.monthly, '2026-02').end,
        DateTime(2026, 3, 1),
      );
      expect(
        periodBounds(PeriodType.monthly, '2028-02').end,
        DateTime(2028, 3, 1),
      );
    });

    test('yearly', () {
      expect(periodBounds(PeriodType.yearly, '2026'), (
        start: DateTime(2026, 1, 1),
        end: DateTime(2027, 1, 1),
      ));
    });

    test('weekly — round-trips with periodKeyFor', () {
      final b = periodBounds(PeriodType.weekly, '2026-W37');
      expect(b.start.weekday, DateTime.monday);
      expect(b.end.difference(b.start).inDays, 7);
      expect(periodKeyFor(b.start, PeriodType.weekly), '2026-W37');
      expect(
        periodKeyFor(
          b.end.subtract(const Duration(days: 1)),
          PeriodType.weekly,
        ),
        '2026-W37',
      );
    });

    test('weekly — the 2026-W53 edge case has valid bounds', () {
      final b = periodBounds(PeriodType.weekly, '2026-W53');
      expect(b.start, DateTime(2026, 12, 28));
      expect(b.end, DateTime(2027, 1, 4));
    });
  });

  group('shiftPeriod', () {
    test('monthly wraps the year', () {
      expect(
        periodKeyFor(
          shiftPeriod(PeriodType.monthly, now, 1),
          PeriodType.monthly,
        ),
        '2026-10',
      );
      expect(
        periodKeyFor(
          shiftPeriod(PeriodType.monthly, now, 4),
          PeriodType.monthly,
        ),
        '2027-01',
      );
      expect(
        periodKeyFor(
          shiftPeriod(PeriodType.monthly, now, -9),
          PeriodType.monthly,
        ),
        '2025-12',
      );
    });
    test('weekly steps 7 days', () {
      expect(
        periodKeyFor(
          shiftPeriod(PeriodType.weekly, DateTime(2026, 9, 8), 1),
          PeriodType.weekly,
        ),
        '2026-W38',
      );
    });
  });

  group('computeAggregates', () {
    test('produces both per-category and period-total rows', () {
      final aggs = computeAggregates(
        transactions: [
          txn(
            DateTime(2026, 9, 3),
            type: TransactionType.expense,
            amountMinor: 500,
            categoryId: 'food',
          ),
          txn(
            DateTime(2026, 9, 4),
            type: TransactionType.expense,
            amountMinor: 300,
            categoryId: 'transport',
          ),
        ],
        userId: 'u',
        now: now,
      );

      final monthlyFood = aggs.firstWhere(
        (a) =>
            a.periodType == PeriodType.monthly &&
            a.periodKey == '2026-09' &&
            a.categoryId == 'food',
      );
      final monthlyTotal = aggs.firstWhere(
        (a) =>
            a.periodType == PeriodType.monthly &&
            a.periodKey == '2026-09' &&
            a.categoryId == null,
      );
      expect(monthlyFood.totalExpenseMinor, 500);
      expect(monthlyTotal.totalExpenseMinor, 800);
      expect(monthlyTotal.transactionCount, 2);
      // Also produced weekly + yearly rows for both.
      expect(
        aggs.where((a) => a.periodType == PeriodType.weekly).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        aggs.where((a) => a.periodType == PeriodType.yearly).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('income and expense stay separate (never netted)', () {
      final aggs = computeAggregates(
        transactions: [
          txn(
            DateTime(2026, 9, 3),
            type: TransactionType.income,
            amountMinor: 10000,
          ),
          txn(
            DateTime(2026, 9, 4),
            type: TransactionType.expense,
            amountMinor: 4000,
          ),
        ],
        userId: 'u',
        now: now,
      );
      final total = aggs.firstWhere(
        (a) => a.periodType == PeriodType.monthly && a.categoryId == null,
      );
      expect(total.totalIncomeMinor, 10000);
      expect(total.totalExpenseMinor, 4000);
      expect(total.netMinor, 6000);
    });

    test('isDeleted transactions are excluded', () {
      final aggs = computeAggregates(
        transactions: [
          txn(
            DateTime(2026, 9, 3),
            type: TransactionType.expense,
            amountMinor: 500,
          ),
          txn(
            DateTime(2026, 9, 4),
            type: TransactionType.expense,
            amountMinor: 999,
            isDeleted: true,
          ),
        ],
        userId: 'u',
        now: now,
      );
      final total = aggs.firstWhere(
        (a) => a.periodType == PeriodType.monthly && a.categoryId == null,
      );
      expect(total.totalExpenseMinor, 500);
      expect(total.transactionCount, 1);
    });

    test('empty input -> no aggregates', () {
      expect(
        computeAggregates(transactions: const [], userId: 'u', now: now),
        isEmpty,
      );
    });

    test(
      'transaction spanning a year boundary lands in the right yearly bucket',
      () {
        final aggs = computeAggregates(
          transactions: [
            txn(
              DateTime(2026, 12, 31),
              type: TransactionType.expense,
              amountMinor: 100,
            ),
            txn(
              DateTime(2027, 1, 1),
              type: TransactionType.expense,
              amountMinor: 200,
            ),
          ],
          userId: 'u',
          now: now,
        );
        final y2026 = aggs.firstWhere(
          (a) =>
              a.periodType == PeriodType.yearly &&
              a.periodKey == '2026' &&
              a.categoryId == null,
        );
        final y2027 = aggs.firstWhere(
          (a) =>
              a.periodType == PeriodType.yearly &&
              a.periodKey == '2027' &&
              a.categoryId == null,
        );
        expect(y2026.totalExpenseMinor, 100);
        expect(y2027.totalExpenseMinor, 200);
      },
    );
  });

  test('aggregateIdsFor returns 6 ids (3 period types x category + total)', () {
    final ids = aggregateIdsFor(
      txn(
        DateTime(2026, 9, 8),
        type: TransactionType.expense,
        categoryId: 'food',
      ),
      'u',
    );
    expect(ids.length, 6);
    expect(ids.toSet().length, 6); // all distinct
    expect(ids.where((id) => id.endsWith('_food')).length, 3);
    expect(ids.where((id) => id.endsWith('_all')).length, 3);
  });
}

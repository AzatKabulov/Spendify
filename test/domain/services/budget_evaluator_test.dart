import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/services/budget_evaluator.dart';

Budget monthlyBudget({String? categoryId, int limitMinor = 100000}) => Budget(
  id: 'b',
  userId: 'u',
  categoryId: categoryId,
  limitAmountMinor: limitMinor,
  period: BudgetPeriod.monthly,
  startDate: DateTime(2020, 1, 1),
  createdAt: DateTime(2020, 1, 1),
  updatedAt: DateTime(2020, 1, 1),
);

Budget weeklyBudget({String? categoryId, int limitMinor = 100000}) => Budget(
  id: 'bw',
  userId: 'u',
  categoryId: categoryId,
  limitAmountMinor: limitMinor,
  period: BudgetPeriod.weekly,
  startDate: DateTime(2020, 1, 1),
  createdAt: DateTime(2020, 1, 1),
  updatedAt: DateTime(2020, 1, 1),
);

Transaction expense(
  int amountMinor,
  DateTime date, {
  String categoryId = 'food',
  bool isDeleted = false,
}) => Transaction(
  id: '$amountMinor-${date.toIso8601String()}-$categoryId',
  userId: 'u',
  amountMinor: amountMinor,
  type: TransactionType.expense,
  categoryId: categoryId,
  date: date,
  source: TransactionSource.manual,
  createdAt: date,
  updatedAt: date,
  isDeleted: isDeleted,
);

Transaction income(
  int amountMinor,
  DateTime date, {
  String categoryId = 'food',
}) => Transaction(
  id: 'inc-$amountMinor-${date.toIso8601String()}',
  userId: 'u',
  amountMinor: amountMinor,
  type: TransactionType.income,
  categoryId: categoryId,
  date: date,
  source: TransactionSource.manual,
  createdAt: date,
  updatedAt: date,
);

void main() {
  final sep15 = DateTime(2026, 9, 15); // a Tuesday

  group('levels', () {
    test('zero transactions -> spent 0, safe', () {
      final s = evaluateBudget(
        budget: monthlyBudget(),
        transactions: const [],
        now: sep15,
      );
      expect(s.spentMinor, 0);
      expect(s.remainingMinor, 100000);
      expect(s.fractionUsed, 0);
      expect(s.level, BudgetLevel.safe);
    });

    test('under limit -> safe', () {
      final s = evaluateBudget(
        budget: monthlyBudget(),
        transactions: [expense(50000, DateTime(2026, 9, 3))],
        now: sep15,
      );
      expect(s.level, BudgetLevel.safe);
      expect(s.fractionUsed, 0.5);
      expect(s.remainingMinor, 50000);
    });

    test('exactly at the 80% threshold -> approaching', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [expense(80000, DateTime(2026, 9, 3))],
        now: sep15,
      );
      expect(s.fractionUsed, 0.8);
      expect(s.level, BudgetLevel.approaching);
    });

    test('just under 80% -> safe', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [expense(79999, DateTime(2026, 9, 3))],
        now: sep15,
      );
      expect(s.level, BudgetLevel.safe);
    });

    test(
      'exactly at 100% -> approaching (documented rule: exceeded is > 1.0)',
      () {
        final s = evaluateBudget(
          budget: monthlyBudget(limitMinor: 100000),
          transactions: [expense(100000, DateTime(2026, 9, 3))],
          now: sep15,
        );
        expect(s.fractionUsed, 1.0);
        expect(s.level, BudgetLevel.approaching);
        expect(s.remainingMinor, 0);
      },
    );

    test('over limit -> exceeded, remaining negative', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [
          expense(90000, DateTime(2026, 9, 3)),
          expense(20000, DateTime(2026, 9, 9)),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 110000);
      expect(s.level, BudgetLevel.exceeded);
      expect(s.remainingMinor, -10000);
      expect(s.fractionUsed, closeTo(1.1, 1e-9));
    });
  });

  group('filtering', () {
    test('income transactions are ignored', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [
          income(500000, DateTime(2026, 9, 5)),
          expense(30000, DateTime(2026, 9, 6)),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 30000);
    });

    test('soft-deleted transactions are excluded', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [
          expense(30000, DateTime(2026, 9, 6)),
          expense(99999, DateTime(2026, 9, 7), isDeleted: true),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 30000);
    });

    test('category budget ignores other categories', () {
      final s = evaluateBudget(
        budget: monthlyBudget(categoryId: 'food', limitMinor: 100000),
        transactions: [
          expense(30000, DateTime(2026, 9, 6), categoryId: 'food'),
          expense(70000, DateTime(2026, 9, 7), categoryId: 'transport'),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 30000);
    });

    test('overall budget includes every category', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 100000),
        transactions: [
          expense(30000, DateTime(2026, 9, 6), categoryId: 'food'),
          expense(70000, DateTime(2026, 9, 7), categoryId: 'transport'),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 100000);
    });
  });

  group('monthly period boundaries', () {
    test('first instant of the month is included, last day included', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [
          expense(100, DateTime(2026, 9, 1)), // first day 00:00
          expense(100, DateTime(2026, 9, 30, 23, 59)), // last day, late
        ],
        now: sep15,
      );
      expect(s.spentMinor, 200);
      expect(s.periodStart, DateTime(2026, 9, 1));
      expect(s.periodEnd, DateTime(2026, 10, 1));
    });

    test('one day before and the first day of next month are excluded', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [
          expense(100, DateTime(2026, 8, 31)),
          expense(100, DateTime(2026, 10, 1)),
        ],
        now: sep15,
      );
      expect(s.spentMinor, 0);
    });

    test('31-day month (August)', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [expense(500, DateTime(2026, 8, 31))],
        now: DateTime(2026, 8, 10),
      );
      expect(s.spentMinor, 500);
      expect(s.periodEnd, DateTime(2026, 9, 1));
    });

    test('30-day month (April)', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [
          expense(500, DateTime(2026, 4, 30)),
          expense(999, DateTime(2026, 5, 1)),
        ],
        now: DateTime(2026, 4, 10),
      );
      expect(s.spentMinor, 500);
      expect(s.periodEnd, DateTime(2026, 5, 1));
    });

    test('February, non-leap year (2026)', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [
          expense(500, DateTime(2026, 2, 28)),
          expense(999, DateTime(2026, 3, 1)),
        ],
        now: DateTime(2026, 2, 14),
      );
      expect(s.spentMinor, 500);
      expect(s.periodEnd, DateTime(2026, 3, 1));
    });

    test('February, leap year (2028) includes the 29th', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [expense(500, DateTime(2028, 2, 29))],
        now: DateTime(2028, 2, 14),
      );
      expect(s.spentMinor, 500);
      expect(s.periodEnd, DateTime(2028, 3, 1));
    });

    test('December rolls the end into next January', () {
      final s = evaluateBudget(
        budget: monthlyBudget(limitMinor: 1000000),
        transactions: [
          expense(500, DateTime(2026, 12, 31)),
          expense(999, DateTime(2027, 1, 1)),
        ],
        now: DateTime(2026, 12, 20),
      );
      expect(s.spentMinor, 500);
      expect(s.periodStart, DateTime(2026, 12, 1));
      expect(s.periodEnd, DateTime(2027, 1, 1));
    });
  });

  group('weekly period boundaries', () {
    test('Monday-start window containing a Tuesday', () {
      // 2026-09-15 is a Tuesday -> week is Mon 2026-09-14 .. Mon 2026-09-21.
      final s = evaluateBudget(
        budget: weeklyBudget(limitMinor: 1000000),
        transactions: [
          expense(100, DateTime(2026, 9, 14)), // Monday, included
          expense(100, DateTime(2026, 9, 20, 23, 59)), // Sunday, included
          expense(999, DateTime(2026, 9, 13)), // prev Sunday, excluded
          expense(999, DateTime(2026, 9, 21)), // next Monday, excluded
        ],
        now: sep15,
      );
      expect(s.spentMinor, 200);
      expect(s.periodStart, DateTime(2026, 9, 14));
      expect(s.periodEnd, DateTime(2026, 9, 21));
    });

    test('evaluating on a Monday uses that Monday as the start', () {
      final s = evaluateBudget(
        budget: weeklyBudget(limitMinor: 1000000),
        transactions: [expense(100, DateTime(2026, 9, 14))],
        now: DateTime(2026, 9, 14), // Monday
      );
      expect(s.periodStart, DateTime(2026, 9, 14));
      expect(s.periodEnd, DateTime(2026, 9, 21));
    });

    test('evaluating on a Sunday still uses the preceding Monday', () {
      final s = evaluateBudget(
        budget: weeklyBudget(limitMinor: 1000000),
        transactions: const [],
        now: DateTime(2026, 9, 20), // Sunday
      );
      expect(s.periodStart, DateTime(2026, 9, 14));
      expect(s.periodEnd, DateTime(2026, 9, 21));
    });

    test('week boundary spanning a month change', () {
      // 2026-10-01 is a Thursday -> week is Mon 2026-09-28 .. Mon 2026-10-05.
      final s = evaluateBudget(
        budget: weeklyBudget(limitMinor: 1000000),
        transactions: [
          expense(100, DateTime(2026, 9, 28)), // Monday (Sept)
          expense(100, DateTime(2026, 10, 1)), // Thursday (Oct)
          expense(100, DateTime(2026, 10, 4)), // Sunday (Oct)
          expense(999, DateTime(2026, 9, 27)), // excluded
          expense(999, DateTime(2026, 10, 5)), // excluded
        ],
        now: DateTime(2026, 10, 1),
      );
      expect(s.spentMinor, 300);
      expect(s.periodStart, DateTime(2026, 9, 28));
      expect(s.periodEnd, DateTime(2026, 10, 5));
    });

    test('week boundary spanning a year change', () {
      // 2027-01-01 is a Friday -> week is Mon 2026-12-28 .. Mon 2027-01-04.
      final s = evaluateBudget(
        budget: weeklyBudget(limitMinor: 1000000),
        transactions: [
          expense(100, DateTime(2026, 12, 31)),
          expense(100, DateTime(2027, 1, 1)),
        ],
        now: DateTime(2027, 1, 1),
      );
      expect(s.spentMinor, 200);
      expect(s.periodStart, DateTime(2026, 12, 28));
      expect(s.periodEnd, DateTime(2027, 1, 4));
    });
  });

  test('overall and category budgets evaluate independently', () {
    final txns = [
      expense(60000, DateTime(2026, 9, 5), categoryId: 'food'),
      expense(60000, DateTime(2026, 9, 6), categoryId: 'transport'),
    ];
    final overall = evaluateBudget(
      budget: monthlyBudget(limitMinor: 100000),
      transactions: txns,
      now: sep15,
    );
    final food = evaluateBudget(
      budget: monthlyBudget(categoryId: 'food', limitMinor: 100000),
      transactions: txns,
      now: sep15,
    );
    expect(overall.spentMinor, 120000);
    expect(overall.level, BudgetLevel.exceeded);
    expect(food.spentMinor, 60000);
    expect(food.level, BudgetLevel.safe);
  });
}

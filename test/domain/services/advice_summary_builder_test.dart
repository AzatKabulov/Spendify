import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/category.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/period_aggregate.dart';
import 'package:spendly/domain/services/advice_summary_builder.dart';

const _now = _Now();

class _Now {
  const _Now();
  DateTime get value => DateTime(2026, 9, 15);
}

PeriodAggregate _agg(
  PeriodType type,
  String key, {
  String? categoryId,
  int expense = 0,
  int income = 0,
  int count = 1,
}) => PeriodAggregate(
  id: PeriodAggregate.buildId(
    userId: 'local-user',
    periodType: type,
    periodKey: key,
    categoryId: categoryId,
  ),
  userId: 'local-user',
  periodType: type,
  periodKey: key,
  categoryId: categoryId,
  totalIncomeMinor: income,
  totalExpenseMinor: expense,
  transactionCount: count,
  updatedAt: DateTime.utc(2026, 9, 15),
);

Category _cat(String id, String name) => Category.create(
  id: id,
  userId: 'local-user',
  name: name,
  iconCode: 0,
  colorValue: 0,
  now: DateTime.utc(2026, 1, 1),
);

Budget _budget(String id, {String? categoryId, required int limit}) =>
    Budget.create(
      id: id,
      userId: 'local-user',
      categoryId: categoryId,
      limitAmountMinor: limit,
      period: BudgetPeriod.monthly,
      startDate: DateTime(2026, 1, 1),
      now: DateTime.utc(2026, 1, 1),
    );

final _categories = <Category>[
  _cat('cat-food', 'Food'),
  _cat('cat-transport', 'Transport'),
  _cat('cat-other', 'Other'),
];

/// RM 2000 income, RM 900 expense. Food 500 (up from 400), Transport 300 (down
/// from 350), Other 100 (new). Logged on 3 distinct days.
List<PeriodAggregate> _scenario() => <PeriodAggregate>[
  _agg(
    PeriodType.monthly,
    '2026-09',
    income: 200000,
    expense: 90000,
    count: 20,
  ),
  _agg(PeriodType.monthly, '2026-09', categoryId: 'cat-food', expense: 50000),
  _agg(
    PeriodType.monthly,
    '2026-09',
    categoryId: 'cat-transport',
    expense: 30000,
  ),
  _agg(PeriodType.monthly, '2026-09', categoryId: 'cat-other', expense: 10000),
  _agg(PeriodType.monthly, '2026-08', categoryId: 'cat-food', expense: 40000),
  _agg(
    PeriodType.monthly,
    '2026-08',
    categoryId: 'cat-transport',
    expense: 35000,
  ),
  _agg(PeriodType.daily, '2026-09-01', expense: 1000),
  _agg(PeriodType.daily, '2026-09-07', expense: 1000),
  _agg(PeriodType.daily, '2026-09-12', expense: 1000),
  // a daily row with no activity should not count
  _agg(PeriodType.daily, '2026-09-13', expense: 0, count: 0),
];

void main() {
  AdviceSummary build({List<Budget> budgets = const []}) => buildAdviceSummary(
    aggregates: _scenario(),
    budgets: budgets,
    categories: _categories,
    now: _now.value,
  );

  group('totals & categories', () {
    test('period totals are whole ringgit', () {
      final s = build();
      expect(s.incomeRm, 2000);
      expect(s.expenseRm, 900);
      expect(s.netRm, 1100);
      expect(s.periodLabel, 'September 2026');
      expect(s.currency, 'MYR');
    });

    test('top categories ranked by spend, with share of expense', () {
      final s = build();
      expect(s.topCategories.map((c) => c.category), [
        'Food',
        'Transport',
        'Other',
      ]);
      expect(s.topCategories.first.spentRm, 500);
      expect(s.topCategories.first.shareOfExpensePct, 56); // 500/900
    });

    test('logging consistency counts distinct active days', () {
      final s = build();
      expect(s.daysLogged, 3);
      expect(s.daysInPeriod, 15); // 1–15 Sep elapsed
    });
  });

  group('trends vs previous period', () {
    test('up / down / new are classified from the previous-period totals', () {
      final trends = {for (final t in build().trends) t.category: t.direction};
      expect(trends['Food'], 'up'); // 500 vs 400
      expect(trends['Transport'], 'down'); // 300 vs 350
      expect(trends['Other'], 'new'); // no spend last month
    });
  });

  group('budget adherence', () {
    test('flags kept vs exceeded with a coarse over-budget percent', () {
      final s = build(
        budgets: <Budget>[
          _budget('b-overall', limit: 100000), // RM 1000, spent RM 900
          _budget('b-food', categoryId: 'cat-food', limit: 45000), // over
        ],
      );
      final overall = s.budgetAdherence.firstWhere((b) => b.scope == 'Overall');
      final food = s.budgetAdherence.firstWhere((b) => b.scope == 'Food');
      expect(overall.exceeded, isFalse);
      expect(food.exceeded, isTrue);
      expect(food.limitRm, 450);
      expect(food.spentRm, 500);
      expect(food.overByPercent, 10); // 11% -> coarse 10
    });
  });

  group('PAYLOAD — data minimisation (CLAUDE.md §7)', () {
    test('toJson carries only aggregates: no ids, merchants, notes, or uid', () {
      final s = build(
        budgets: <Budget>[
          _budget('b-food', categoryId: 'cat-food', limit: 45000),
        ],
      );
      final json = jsonEncode(s.toJson());

      // category *names* are allowed (advice must reference real categories)
      expect(json, contains('Food'));

      // category IDs, user id, and any raw-transaction concepts are NOT present
      for (final forbidden in <String>[
        'cat-food',
        'cat-transport',
        'local-user',
        'userId',
        'merchant',
        'note',
        'transactionId',
        r'"id"',
      ]) {
        expect(
          json.toLowerCase(),
          isNot(contains(forbidden.toLowerCase())),
          reason: 'payload must not contain "$forbidden"',
        );
      }
    });

    test('every money value is a whole-ringgit integer (no sen precision)', () {
      final json = build().toJson();
      final totals = json['totals']! as Map<String, Object?>;
      expect(totals['expense'], isA<int>());
      expect(totals['income'], isA<int>());
      for (final c in json['topCategories']! as List<Object?>) {
        expect((c! as Map)['spent'], isA<int>());
      }
      // No decimal points anywhere in the serialised payload.
      expect(jsonEncode(json), isNot(contains('.')));
    });

    test('the hash-stable form drops clock-driven fields', () {
      final full = build().toJson();
      final stable = build().toJson(stableOnly: true);
      expect(full.containsKey('transactionCount'), isTrue);
      expect(stable.containsKey('transactionCount'), isFalse);
      expect(
        (stable['loggingConsistency']! as Map).containsKey('daysInPeriod'),
        isFalse,
      );
    });
  });

  test('empty month: no categories, zeroed totals, still a valid summary', () {
    final s = buildAdviceSummary(
      aggregates: const <PeriodAggregate>[],
      budgets: const <Budget>[],
      categories: _categories,
      now: _now.value,
    );
    expect(s.expenseRm, 0);
    expect(s.topCategories, isEmpty);
    expect(s.trends, isEmpty);
    expect(s.daysLogged, 0);
  });
}

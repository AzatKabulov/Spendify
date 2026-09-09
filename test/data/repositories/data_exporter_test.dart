import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/data/repositories/data_exporter.dart';
import 'package:spendly/domain/entities/budget.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/gamification_state.dart';
import 'package:spendly/domain/entities/transaction.dart';

import '../../support/fake_repositories.dart';

void main() {
  late FakeTransactionRepository txns;
  late FakeCategoryRepository cats;
  late FakeBudgetRepository budgets;
  late FakeGamificationStateRepository gamification;
  late DataExporter exporter;

  setUp(() async {
    txns = FakeTransactionRepository();
    cats = FakeCategoryRepository();
    budgets = FakeBudgetRepository();
    gamification = FakeGamificationStateRepository(userId: 'local-user');
    await cats.ensureDefaultsSeeded();
    exporter = DataExporter(
      transactions: txns,
      categories: cats,
      budgets: budgets,
      gamification: gamification,
    );
  });

  Transaction txn(String id, {int amount = 1500, String? note}) =>
      Transaction.create(
        id: id,
        userId: 'local-user',
        amountMinor: amount,
        type: TransactionType.expense,
        categoryId: 'cat-0',
        date: DateTime(2026, 9, 6),
        now: DateTime.utc(2026, 9, 6),
        note: note,
      );

  test('produces valid, parseable JSON with every section', () async {
    await txns.add(txn('t1', note: 'lunch'));
    await txns.add(txn('t2', amount: 800));
    await budgets.add(
      Budget.create(
        id: 'b1',
        userId: 'local-user',
        limitAmountMinor: 50000,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 9, 1),
        now: DateTime.utc(2026, 9, 1),
      ),
    );
    await gamification.save(
      GamificationState(
        userId: 'local-user',
        updatedAt: DateTime.utc(2026, 9, 6),
        xp: 40,
        coins: 12,
        transactionsLogged: 2,
      ),
    );

    final raw = await exporter.buildJsonString(
      generatedAt: DateTime.utc(2026, 9, 10, 8),
      account: 'demo@example.com',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    expect(decoded['export'], isA<Map<String, dynamic>>());
    expect(decoded['export']['app'], 'Spendly');
    expect(decoded['export']['account'], 'demo@example.com');
    expect(decoded['export']['generatedAt'], '2026-09-10T08:00:00.000Z');

    final txList = decoded['transactions'] as List;
    expect(txList, hasLength(2));
    expect(txList.first['id'], 't1');
    expect(txList.first['amountMinor'], 1500);
    expect(txList.first['note'], 'lunch');
    expect(txList.first['date'], '2026-09-06');

    expect((decoded['categories'] as List).length, greaterThanOrEqualTo(8));
    expect((decoded['budgets'] as List).single['limitAmountMinor'], 50000);

    expect(decoded['gamification']['xp'], 40);
    expect(decoded['gamification']['transactionsLogged'], 2);

    expect(decoded['counts']['transactions'], 2);
  });

  test('includes soft-deleted rows, marked deleted', () async {
    await txns.add(txn('keep'));
    await txns.add(txn('gone'));
    await txns.delete('gone');

    final decoded =
        jsonDecode(
              await exporter.buildJsonString(
                generatedAt: DateTime.utc(2026, 9, 10),
              ),
            )
            as Map<String, dynamic>;

    final byId = {for (final t in decoded['transactions'] as List) t['id']: t};
    expect(byId['keep']['deleted'], isNull);
    expect(byId['gone']['deleted'], true);
    // counts reflect live rows only
    expect(decoded['counts']['transactions'], 1);
  });

  test(
    'account is omitted when signed out; gamification null when none',
    () async {
      final decoded =
          jsonDecode(
                await exporter.buildJsonString(
                  generatedAt: DateTime.utc(2026, 9, 10),
                ),
              )
              as Map<String, dynamic>;
      expect(decoded['export'].containsKey('account'), isFalse);
      expect(decoded['gamification'], isNull);
      expect(decoded['transactions'], isEmpty);
    },
  );
}

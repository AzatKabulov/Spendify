import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:spendify/data/local/hive_registrar.dart';
import 'package:spendify/data/local/hive_types.dart';
import 'package:spendify/data/local/models/budget_model.dart';
import 'package:spendify/data/local/models/period_aggregate_model.dart';
import 'package:spendify/data/local/models/transaction_model.dart';
import 'package:spendify/domain/entities/enums.dart';

import '../../support/hive_test_harness.dart';

void main() {
  test('enum adapters are registered at the reserved typeIds', () {
    registerSpendifyHiveAdapters();
    expect(Hive.isAdapterRegistered(HiveTypeIds.transactionType), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.transactionSource), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.budgetPeriod), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.periodType), isTrue);
    expect(Hive.isAdapterRegistered(HiveTypeIds.syncStatus), isTrue);
  });

  test('every enum value survives a real encrypted box round-trip', () async {
    final harness = await HiveTestHarness.start();
    addTearDown(harness.dispose);

    final ts = DateTime.utc(2026, 9, 6);

    for (final type in TransactionType.values) {
      for (final source in TransactionSource.values) {
        for (final status in SyncStatus.values) {
          final key = '${type.name}_${source.name}_${status.name}';
          await harness.store.transactions.put(
            key,
            TransactionModel(
              id: key,
              userId: 'u',
              amountMinor: 1,
              type: type,
              categoryId: 'c',
              date: ts,
              source: source,
              createdAt: ts,
              updatedAt: ts,
              isDeleted: false,
              syncStatus: status,
            ),
          );
          final got = harness.store.transactions.get(key)!;
          expect(got.type, type);
          expect(got.source, source);
          expect(got.syncStatus, status);
        }
      }
    }

    for (final period in BudgetPeriod.values) {
      await harness.store.budgets.put(
        period.name,
        BudgetModel(
          id: period.name,
          userId: 'u',
          limitAmountMinor: 1,
          period: period,
          startDate: ts,
          createdAt: ts,
          updatedAt: ts,
          isDeleted: false,
          syncStatus: SyncStatus.pending,
        ),
      );
      expect(harness.store.budgets.get(period.name)!.period, period);
    }

    for (final pt in PeriodType.values) {
      await harness.store.periodAggregates.put(
        pt.name,
        PeriodAggregateModel(
          id: pt.name,
          userId: 'u',
          periodType: pt,
          periodKey: '2026',
          totalIncomeMinor: 0,
          totalExpenseMinor: 0,
          transactionCount: 0,
          updatedAt: ts,
        ),
      );
      expect(harness.store.periodAggregates.get(pt.name)!.periodType, pt);
    }
  });
}

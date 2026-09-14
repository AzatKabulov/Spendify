import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/patch.dart';
import 'package:spendify/domain/entities/transaction.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = DateTime.utc(2026, 2, 2);

  group('markUpdated / markDeleted / markSynced', () {
    final txn = Transaction(
      id: 't',
      userId: 'u',
      amountMinor: 100,
      type: TransactionType.expense,
      categoryId: 'c',
      date: t0,
      source: TransactionSource.manual,
      createdAt: t0,
      updatedAt: t0,
      syncStatus: SyncStatus.synced,
    );

    test(
      'markUpdated bumps updatedAt and sets pending, keeps createdAt/id',
      () {
        final u = txn.markUpdated(at: t1);
        expect(u.updatedAt, t1);
        expect(u.syncStatus, SyncStatus.pending);
        expect(u.createdAt, t0);
        expect(u.id, 't');
        expect(u.isDeleted, isFalse);
      },
    );

    test('markDeleted sets the tombstone plus updatedAt + pending', () {
      final d = txn.markDeleted(at: t1);
      expect(d.isDeleted, isTrue);
      expect(d.updatedAt, t1);
      expect(d.syncStatus, SyncStatus.pending);
    });

    test('markSynced only flips syncStatus', () {
      final s = txn.markUpdated(at: t1).markSynced();
      expect(s.syncStatus, SyncStatus.synced);
      expect(s.updatedAt, t1);
    });
  });

  test('copyWith patch clears a nullable field; plain omit keeps it', () {
    final txn = Transaction(
      id: 't',
      userId: 'u',
      amountMinor: 100,
      type: TransactionType.expense,
      categoryId: 'c',
      date: t0,
      note: 'keep me',
      source: TransactionSource.manual,
      createdAt: t0,
      updatedAt: t0,
    );
    expect(txn.copyWith(amountMinor: 200).note, 'keep me');
    expect(txn.copyWith(note: patch<String?>(null)).note, isNull);
  });

  test('value equality is structural', () {
    Category make() => Category(
      id: 'c',
      userId: 'u',
      name: 'X',
      iconCode: 1,
      colorValue: 2,
      createdAt: t0,
      updatedAt: t0,
    );
    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(equals(make().copyWith(name: 'Y'))));
  });

  test('Budget.isOverall reflects a null categoryId', () {
    final b = Budget(
      id: 'b',
      userId: 'u',
      limitAmountMinor: 1,
      period: BudgetPeriod.weekly,
      startDate: t0,
      createdAt: t0,
      updatedAt: t0,
    );
    expect(b.isOverall, isTrue);
    expect(b.copyWith(categoryId: patch<String?>('c')).isOverall, isFalse);
  });

  test('negative money is rejected at construction', () {
    expect(
      () => Transaction(
        id: 't',
        userId: 'u',
        amountMinor: -1,
        type: TransactionType.expense,
        categoryId: 'c',
        date: t0,
        source: TransactionSource.manual,
        createdAt: t0,
        updatedAt: t0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/services/transaction_ordering.dart';

Transaction txn({
  required String id,
  required DateTime date,
  required DateTime createdAt,
}) => Transaction(
  id: id,
  userId: 'u',
  amountMinor: 100,
  type: TransactionType.expense,
  categoryId: 'c',
  date: date,
  source: TransactionSource.manual,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  test('newest transaction date first', () {
    final list = sortTransactionsForDisplay([
      txn(id: 'a', date: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 1)),
      txn(id: 'c', date: DateTime(2026, 9, 3), createdAt: DateTime(2026, 9, 3)),
      txn(id: 'b', date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2)),
    ]);
    expect(list.map((t) => t.id), <String>['c', 'b', 'a']);
  });

  test('same day: newest createdAt first', () {
    final day = DateTime(2026, 9, 5);
    final list = sortTransactionsForDisplay([
      txn(id: 'early', date: day, createdAt: DateTime(2026, 9, 5, 8)),
      txn(id: 'late', date: day, createdAt: DateTime(2026, 9, 5, 20)),
      txn(id: 'mid', date: day, createdAt: DateTime(2026, 9, 5, 12)),
    ]);
    expect(list.map((t) => t.id), <String>['late', 'mid', 'early']);
  });

  test(
    'date beats createdAt: a backdated entry created now still sorts by date',
    () {
      final list = sortTransactionsForDisplay([
        // created most recently, but for an old date
        txn(
          id: 'backdated',
          date: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 9, 9),
        ),
        txn(
          id: 'today',
          date: DateTime(2026, 9, 8),
          createdAt: DateTime(2026, 9, 8),
        ),
      ]);
      expect(list.map((t) => t.id), <String>['today', 'backdated']);
    },
  );

  test('fully-tied entries fall back to id for a stable order', () {
    final d = DateTime(2026, 9, 5);
    final a = txn(id: 'aaa', date: d, createdAt: d);
    final b = txn(id: 'bbb', date: d, createdAt: d);
    expect(sortTransactionsForDisplay([b, a]).map((t) => t.id), ['aaa', 'bbb']);
    expect(sortTransactionsForDisplay([a, b]).map((t) => t.id), ['aaa', 'bbb']);
  });

  test('does not mutate the input list', () {
    final input = [
      txn(id: 'a', date: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 1)),
      txn(id: 'b', date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2)),
    ];
    sortTransactionsForDisplay(input);
    expect(input.map((t) => t.id), <String>['a', 'b']);
  });
}

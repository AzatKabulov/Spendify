import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/services/balance_calculator.dart';

Transaction txn(
  TransactionType type,
  int amountMinor, {
  bool isDeleted = false,
}) => Transaction(
  id: '${type.name}-$amountMinor-$isDeleted',
  userId: 'u',
  amountMinor: amountMinor,
  type: type,
  categoryId: 'c',
  date: DateTime(2026, 9, 1),
  source: TransactionSource.manual,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  isDeleted: isDeleted,
);

void main() {
  test('empty -> zero', () {
    expect(calculateBalanceMinor(const []), 0);
    expect(calculateTotals(const []), (incomeMinor: 0, expenseMinor: 0));
  });

  test('income adds, expense subtracts', () {
    final list = [
      txn(TransactionType.income, 5000),
      txn(TransactionType.expense, 1500),
      txn(TransactionType.expense, 800),
    ];
    expect(calculateBalanceMinor(list), 5000 - 1500 - 800);
    expect(calculateTotals(list), (incomeMinor: 5000, expenseMinor: 2300));
  });

  test('deleted transactions are ignored', () {
    final list = [
      txn(TransactionType.income, 5000),
      txn(TransactionType.expense, 9999, isDeleted: true),
    ];
    expect(calculateBalanceMinor(list), 5000);
    expect(calculateTotals(list).expenseMinor, 0);
  });

  test('balance can go negative', () {
    expect(calculateBalanceMinor([txn(TransactionType.expense, 2500)]), -2500);
  });
}

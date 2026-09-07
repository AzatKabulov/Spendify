import '../../../domain/entities/transaction.dart';
import '../models/transaction_model.dart';

/// DTO <-> entity conversion for transactions. The only code that knows both
/// shapes; keeps `domain/` and the Hive layer independent (CLAUDE.md §3).
extension TransactionModelMapper on TransactionModel {
  Transaction toDomain() => Transaction(
    id: id,
    userId: userId,
    amountMinor: amountMinor,
    type: type,
    categoryId: categoryId,
    date: date,
    note: note,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

extension TransactionEntityMapper on Transaction {
  TransactionModel toModel() => TransactionModel(
    id: id,
    userId: userId,
    amountMinor: amountMinor,
    type: type,
    categoryId: categoryId,
    date: date,
    note: note,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    syncStatus: syncStatus,
  );
}

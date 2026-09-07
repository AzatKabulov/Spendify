import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../local/mappers/transaction_mapper.dart';
import '../local/models/transaction_model.dart';
import 'base_syncable_hive_repository.dart';

class HiveTransactionRepository
    extends BaseSyncableHiveRepository<Transaction, TransactionModel>
    implements TransactionRepository {
  HiveTransactionRepository(super.box, {super.clock});

  @override
  TransactionModel toModel(Transaction entity) => entity.toModel();

  @override
  Transaction toDomain(TransactionModel model) => model.toDomain();

  @override
  Future<List<Transaction>> getInDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final all = await getAll();
    return all
        .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<Transaction>> getByCategory(String categoryId) async {
    final all = await getAll();
    return all.where((t) => t.categoryId == categoryId).toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

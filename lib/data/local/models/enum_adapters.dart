import 'package:hive/hive.dart';

import '../../../domain/entities/enums.dart';
import '../hive_types.dart';

/// Hand-written Hive adapters for the domain enums (typeIds 10–14).
///
/// The domain enums stay plain Dart (no `@HiveType`) so `domain/` keeps zero
/// Hive imports (CLAUDE.md §3). These adapters — which live in the data layer —
/// bridge them. Each writes the enum's [Enum.index] as a single byte; reads
/// clamp to a safe fallback if an unknown ordinal is ever encountered (forward
/// compatibility if an enum gains values).

class _EnumByIndexAdapter<T extends Enum> extends TypeAdapter<T> {
  _EnumByIndexAdapter(this.typeId, this._values, this._fallback);

  @override
  final int typeId;

  final List<T> _values;
  final T _fallback;

  @override
  T read(BinaryReader reader) {
    final index = reader.readByte();
    if (index < 0 || index >= _values.length) return _fallback;
    return _values[index];
  }

  @override
  void write(BinaryWriter writer, T obj) => writer.writeByte(obj.index);
}

class TransactionTypeAdapter extends _EnumByIndexAdapter<TransactionType> {
  TransactionTypeAdapter()
    : super(
        HiveTypeIds.transactionType,
        TransactionType.values,
        TransactionType.expense,
      );
}

class TransactionSourceAdapter extends _EnumByIndexAdapter<TransactionSource> {
  TransactionSourceAdapter()
    : super(
        HiveTypeIds.transactionSource,
        TransactionSource.values,
        TransactionSource.manual,
      );
}

class BudgetPeriodAdapter extends _EnumByIndexAdapter<BudgetPeriod> {
  BudgetPeriodAdapter()
    : super(
        HiveTypeIds.budgetPeriod,
        BudgetPeriod.values,
        BudgetPeriod.monthly,
      );
}

class PeriodTypeAdapter extends _EnumByIndexAdapter<PeriodType> {
  PeriodTypeAdapter()
    : super(HiveTypeIds.periodType, PeriodType.values, PeriodType.monthly);
}

class SyncStatusAdapter extends _EnumByIndexAdapter<SyncStatus> {
  SyncStatusAdapter()
    : super(HiveTypeIds.syncStatus, SyncStatus.values, SyncStatus.pending);
}

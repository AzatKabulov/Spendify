// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_aggregate_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeriodAggregateModelAdapter extends TypeAdapter<PeriodAggregateModel> {
  @override
  final int typeId = 5;

  @override
  PeriodAggregateModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeriodAggregateModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      periodType: fields[2] as PeriodType,
      periodKey: fields[3] as String,
      totalIncomeMinor: fields[5] as int,
      totalExpenseMinor: fields[6] as int,
      transactionCount: fields[7] as int,
      updatedAt: fields[8] as DateTime,
      categoryId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PeriodAggregateModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.periodType)
      ..writeByte(3)
      ..write(obj.periodKey)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.totalIncomeMinor)
      ..writeByte(6)
      ..write(obj.totalExpenseMinor)
      ..writeByte(7)
      ..write(obj.transactionCount)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodAggregateModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advice_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdviceRecordModelAdapter extends TypeAdapter<AdviceRecordModel> {
  @override
  final int typeId = 4;

  @override
  AdviceRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdviceRecordModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      generatedAt: fields[2] as DateTime,
      summaryHash: fields[3] as String,
      adviceItems: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdviceRecordModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.generatedAt)
      ..writeByte(3)
      ..write(obj.summaryHash)
      ..writeByte(4)
      ..write(obj.adviceItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdviceRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

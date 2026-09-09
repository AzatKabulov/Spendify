// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_state_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GamificationStateModelAdapter
    extends TypeAdapter<GamificationStateModel> {
  @override
  final int typeId = 3;

  @override
  GamificationStateModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GamificationStateModel(
      userId: fields[0] as String,
      xp: fields[1] as int,
      coins: fields[2] as int,
      level: fields[3] as int,
      currentStreak: fields[4] as int,
      longestStreak: fields[5] as int,
      unlockedBadgeIds: (fields[7] as List).cast<String>(),
      updatedAt: fields[8] as DateTime,
      syncStatus: fields[9] as SyncStatus,
      lastActivityDate: fields[6] as DateTime?,
      transactionsLogged: fields[10] as int,
      budgetsCreated: fields[11] as int,
      budgetPeriodsWithinLimit: fields[12] as int,
      scannedTransactionsLogged: fields[13] as int,
      recentEventIds: (fields[14] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, GamificationStateModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.xp)
      ..writeByte(2)
      ..write(obj.coins)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.currentStreak)
      ..writeByte(5)
      ..write(obj.longestStreak)
      ..writeByte(6)
      ..write(obj.lastActivityDate)
      ..writeByte(7)
      ..write(obj.unlockedBadgeIds)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.syncStatus)
      ..writeByte(10)
      ..write(obj.transactionsLogged)
      ..writeByte(11)
      ..write(obj.budgetsCreated)
      ..writeByte(12)
      ..write(obj.budgetPeriodsWithinLimit)
      ..writeByte(13)
      ..write(obj.scannedTransactionsLogged)
      ..writeByte(14)
      ..write(obj.recentEventIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamificationStateModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

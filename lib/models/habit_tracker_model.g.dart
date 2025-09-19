// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_tracker_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitTrackerModelAdapter extends TypeAdapter<HabitTrackerModel> {
  @override
  final int typeId = 8;

  @override
  HabitTrackerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitTrackerModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      type: fields[3] as String,
      targetId: fields[4] as String?,
      frequency: fields[5] as String,
      targetCount: fields[6] as int,
      completedDates: (fields[7] as List).cast<DateTime>(),
      createdAt: fields[8] as DateTime,
      archivedAt: fields[9] as DateTime?,
      isActive: fields[10] as bool,
      iconName: fields[11] as String?,
      color: fields[12] as String?,
      tags: (fields[13] as List).cast<String>(),
      weeklyStats: (fields[14] as Map).cast<String, int>(),
      currentStreak: fields[15] as int,
      longestStreak: fields[16] as int,
      lastCompletedAt: fields[17] as DateTime?,
      notes: (fields[18] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, HabitTrackerModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.targetId)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.targetCount)
      ..writeByte(7)
      ..write(obj.completedDates)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.archivedAt)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.iconName)
      ..writeByte(12)
      ..write(obj.color)
      ..writeByte(13)
      ..write(obj.tags)
      ..writeByte(14)
      ..write(obj.weeklyStats)
      ..writeByte(15)
      ..write(obj.currentStreak)
      ..writeByte(16)
      ..write(obj.longestStreak)
      ..writeByte(17)
      ..write(obj.lastCompletedAt)
      ..writeByte(18)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitTrackerModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timed_workout_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimedWorkoutItemAdapter extends TypeAdapter<TimedWorkoutItem> {
  @override
  final int typeId = 24;

  @override
  TimedWorkoutItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedWorkoutItem(
      workoutId: fields[0] as String,
      time: fields[1] as int,
      useTimed: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TimedWorkoutItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.workoutId)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.useTimed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedWorkoutItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimedWorkoutModelAdapter extends TypeAdapter<TimedWorkoutModel> {
  @override
  final int typeId = 25;

  @override
  TimedWorkoutModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedWorkoutModel(
      id: fields[0] as String,
      name: fields[1] as String,
      workoutOrder: (fields[2] as List).cast<TimedWorkoutItem>(),
      createdAt: fields[3] as DateTime,
      modifiedAt: fields[4] as DateTime?,
      isCustom: fields[5] as bool,
      imageUrl: fields[6] as String?,
      isBookmarked: fields[7] as bool,
      timesPerformed: fields[8] as int,
      completionDates: (fields[9] as List).cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, TimedWorkoutModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.workoutOrder)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modifiedAt)
      ..writeByte(5)
      ..write(obj.isCustom)
      ..writeByte(6)
      ..write(obj.imageUrl)
      ..writeByte(7)
      ..write(obj.isBookmarked)
      ..writeByte(8)
      ..write(obj.timesPerformed)
      ..writeByte(9)
      ..write(obj.completionDates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedWorkoutModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

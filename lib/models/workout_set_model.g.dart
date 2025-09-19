// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_set_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSetModelAdapter extends TypeAdapter<WorkoutSetModel> {
  @override
  final int typeId = 5;

  @override
  WorkoutSetModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSetModel(
      id: fields[0] as String,
      exerciseId: fields[1] as String,
      reps: fields[2] as int,
      weight: fields[3] as double?,
      duration: fields[4] as int?,
      distance: fields[5] as double?,
      restTimeSeconds: fields[6] as int,
      isCompleted: fields[7] as bool,
      completedAt: fields[8] as DateTime?,
      notes: fields[9] as String?,
      targetReps: fields[10] as int?,
      targetWeight: fields[11] as double?,
      targetDuration: fields[12] as int?,
      targetDistance: fields[13] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSetModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.distance)
      ..writeByte(6)
      ..write(obj.restTimeSeconds)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.targetReps)
      ..writeByte(11)
      ..write(obj.targetWeight)
      ..writeByte(12)
      ..write(obj.targetDuration)
      ..writeByte(13)
      ..write(obj.targetDistance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSetModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

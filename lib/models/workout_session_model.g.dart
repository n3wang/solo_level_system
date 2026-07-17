// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionModelAdapter extends TypeAdapter<WorkoutSessionModel> {
  @override
  final int typeId = 7;

  @override
  WorkoutSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSessionModel(
      id: fields[0] as String,
      routineId: fields[1] as String,
      routineName: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      durationMinutes: fields[5] as int,
      completedExerciseIds: (fields[6] as List).cast<String>(),
      exerciseCompletedSets: (fields[7] as Map).cast<String, int>(),
      isCompleted: fields[8] as bool,
      status: fields[9] as String,
      notes: fields[10] as String?,
      totalWeightLifted: fields[11] as double?,
      totalSetsCompleted: fields[12] as int,
      totalRepsCompleted: fields[13] as int,
      personalRecordsSet: (fields[14] as List).cast<String>(),
      averageHeartRate: fields[16] as double?,
      tags: (fields[17] as List).cast<String>(),
      location: fields[18] as String?,
      additionalData: (fields[19] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSessionModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routineId)
      ..writeByte(2)
      ..write(obj.routineName)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.completedExerciseIds)
      ..writeByte(7)
      ..write(obj.exerciseCompletedSets)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.totalWeightLifted)
      ..writeByte(12)
      ..write(obj.totalSetsCompleted)
      ..writeByte(13)
      ..write(obj.totalRepsCompleted)
      ..writeByte(14)
      ..write(obj.personalRecordsSet)
      ..writeByte(15)
      ..write(0) // legacy caloriesBurned slot
      ..writeByte(16)
      ..write(obj.averageHeartRate)
      ..writeByte(17)
      ..write(obj.tags)
      ..writeByte(18)
      ..write(obj.location)
      ..writeByte(19)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

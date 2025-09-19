// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_routine_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutRoutineModelAdapter extends TypeAdapter<WorkoutRoutineModel> {
  @override
  final int typeId = 6;

  @override
  WorkoutRoutineModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutRoutineModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      exerciseIds: (fields[3] as List).cast<String>(),
      exerciseSets: (fields[4] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<WorkoutSetModel>())),
      category: fields[5] as String,
      difficulty: fields[6] as String,
      estimatedDurationMinutes: fields[7] as int,
      tags: (fields[8] as List).cast<String>(),
      isTemplate: fields[9] as bool,
      isFavorite: fields[10] as bool,
      createdAt: fields[11] as DateTime,
      modifiedAt: fields[12] as DateTime?,
      timesCompleted: fields[13] as int,
      lastCompletedAt: fields[14] as DateTime?,
      isArchived: fields[15] as bool,
      notes: fields[16] as String?,
      targetMuscleGroups: (fields[17] as List).cast<String>(),
      createdBy: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutRoutineModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.exerciseIds)
      ..writeByte(4)
      ..write(obj.exerciseSets)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.estimatedDurationMinutes)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.isTemplate)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.modifiedAt)
      ..writeByte(13)
      ..write(obj.timesCompleted)
      ..writeByte(14)
      ..write(obj.lastCompletedAt)
      ..writeByte(15)
      ..write(obj.isArchived)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.targetMuscleGroups)
      ..writeByte(18)
      ..write(obj.createdBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutRoutineModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

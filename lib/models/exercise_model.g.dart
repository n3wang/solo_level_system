// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseModelAdapter extends TypeAdapter<ExerciseModel> {
  @override
  final int typeId = 4;

  @override
  ExerciseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      muscleGroup: fields[4] as String,
      equipment: fields[5] as String,
      difficulty: fields[6] as String,
      instructions: (fields[7] as List).cast<String>(),
      videoUrl: fields[8] as String?,
      imageUrl: fields[9] as String?,
      isCustom: fields[10] as bool,
      createdAt: fields[11] as DateTime,
      modifiedAt: fields[12] as DateTime?,
      tags: (fields[13] as List).cast<String>(),
      isArchived: fields[14] as bool,
      timesPerformed: fields[15] as int,
      personalRecord: fields[16] as double?,
      personalRecordUnit: fields[17] as String?,
      personalRecordDate: fields[18] as DateTime?,
      lastWorkoutReps: (fields[19] as List?)?.cast<int>(),
      lastWorkoutWeights: (fields[20] as List?)?.cast<double?>(),
      lastWorkoutDate: fields[21] as DateTime?,
      measurementUnit: fields[22] as String,
      isBookmarked: fields[23] as bool,
      audioFile: fields[24] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.muscleGroup)
      ..writeByte(5)
      ..write(obj.equipment)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.instructions)
      ..writeByte(8)
      ..write(obj.videoUrl)
      ..writeByte(9)
      ..write(obj.imageUrl)
      ..writeByte(10)
      ..write(obj.isCustom)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.modifiedAt)
      ..writeByte(13)
      ..write(obj.tags)
      ..writeByte(14)
      ..write(obj.isArchived)
      ..writeByte(15)
      ..write(obj.timesPerformed)
      ..writeByte(16)
      ..write(obj.personalRecord)
      ..writeByte(17)
      ..write(obj.personalRecordUnit)
      ..writeByte(18)
      ..write(obj.personalRecordDate)
      ..writeByte(19)
      ..write(obj.lastWorkoutReps)
      ..writeByte(20)
      ..write(obj.lastWorkoutWeights)
      ..writeByte(21)
      ..write(obj.lastWorkoutDate)
      ..writeByte(22)
      ..write(obj.measurementUnit)
      ..writeByte(23)
      ..write(obj.isBookmarked)
      ..writeByte(24)
      ..write(obj.audioFile);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

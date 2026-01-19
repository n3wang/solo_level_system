// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_set_category_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSetCategoryModelAdapter
    extends TypeAdapter<WorkoutSetCategoryModel> {
  @override
  final int typeId = 15;

  @override
  WorkoutSetCategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSetCategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      position: fields[2] as int,
      description: fields[3] as String,
      exerciseIds: (fields[4] as List).cast<String>(),
      color: fields[5] as String?,
      isActive: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      modifiedAt: fields[8] as DateTime?,
      lastPerformanceDate: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSetCategoryModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.exerciseIds)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.modifiedAt)
      ..writeByte(9)
      ..write(obj.lastPerformanceDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSetCategoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

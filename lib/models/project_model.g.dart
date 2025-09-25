// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectModelAdapter extends TypeAdapter<ProjectModel> {
  @override
  final int typeId = 20;

  @override
  ProjectModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      color: fields[3] as String,
      iconName: fields[4] as String?,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      archivedAt: fields[7] as DateTime?,
      habitIds: (fields[8] as List).cast<String>(),
      weeklyPomodoroTargets: (fields[9] as Map).cast<int, int>(),
      activeDays: (fields[10] as List).cast<int>(),
      totalCompletedPomodoros: fields[11] as int,
      lastWorkedOn: fields[12] as DateTime?,
      dailyStats: (fields[13] as Map).cast<String, int>(),
      priority: fields[14] as int,
      notes: fields[15] as String?,
      tags: (fields[16] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.iconName)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.archivedAt)
      ..writeByte(8)
      ..write(obj.habitIds)
      ..writeByte(9)
      ..write(obj.weeklyPomodoroTargets)
      ..writeByte(10)
      ..write(obj.activeDays)
      ..writeByte(11)
      ..write(obj.totalCompletedPomodoros)
      ..writeByte(12)
      ..write(obj.lastWorkedOn)
      ..writeByte(13)
      ..write(obj.dailyStats)
      ..writeByte(14)
      ..write(obj.priority)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

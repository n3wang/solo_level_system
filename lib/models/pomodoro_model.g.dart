// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PomodoroModelAdapter extends TypeAdapter<PomodoroModel> {
  @override
  final int typeId = 0;

  @override
  PomodoroModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PomodoroModel(
      startTime: fields[0] as DateTime,
      audioPath: fields[1] as String?,
      imagePath: fields[2] as String?,
      dayPomodoroNumber: fields[3] as int?,
      duration: fields[4] as String?,
      project_id: fields[5] as String?,
      project_name: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PomodoroModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.audioPath)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.dayPomodoroNumber)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.project_id)
      ..writeByte(6)
      ..write(obj.project_name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

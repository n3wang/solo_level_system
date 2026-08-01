// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryModelAdapter extends TypeAdapter<JournalEntryModel> {
  @override
  final int typeId = 29;

  @override
  JournalEntryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntryModel(
      id: fields[0] as String,
      type: fields[1] as String,
      createdAt: fields[2] as DateTime,
      text: fields[3] as String?,
      mediaPath: fields[4] as String?,
      durationMs: fields[5] as int?,
      projectName: fields[6] as String?,
      sessionMinutes: fields[7] as int?,
      source: fields[8] as String? ?? 'free',
      metadata: (fields[9] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntryModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.mediaPath)
      ..writeByte(5)
      ..write(obj.durationMs)
      ..writeByte(6)
      ..write(obj.projectName)
      ..writeByte(7)
      ..write(obj.sessionMinutes)
      ..writeByte(8)
      ..write(obj.source)
      ..writeByte(9)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'long_break_queue_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LongBreakQueueItemModelAdapter
    extends TypeAdapter<LongBreakQueueItemModel> {
  @override
  final int typeId = 28;

  @override
  LongBreakQueueItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LongBreakQueueItemModel(
      id: fields[0] as String,
      url: fields[1] as String,
      customName: fields[2] as String?,
      hasChapters: fields[3] as bool,
      currentChapter: fields[4] as int,
      isCompleted: fields[5] as bool,
      isArchived: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LongBreakQueueItemModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.customName)
      ..writeByte(3)
      ..write(obj.hasChapters)
      ..writeByte(4)
      ..write(obj.currentChapter)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.isArchived)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LongBreakQueueItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motivation_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MotivationItemModelAdapter extends TypeAdapter<MotivationItemModel> {
  @override
  final int typeId = 26;

  @override
  MotivationItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotivationItemModel(
      id: fields[0] as String,
      type: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String,
      category: fields[4] as String,
      pointsCost: fields[5] as int,
      isAcquired: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      acquiredAt: fields[8] as DateTime?,
      isSystem: fields[9] as bool,
      quotePerson: fields[10] as String?,
      quoteText: fields[11] as String?,
      imageIndex: fields[12] as int?,
      metadata: (fields[13] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MotivationItemModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.pointsCost)
      ..writeByte(6)
      ..write(obj.isAcquired)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.acquiredAt)
      ..writeByte(9)
      ..write(obj.isSystem)
      ..writeByte(10)
      ..write(obj.quotePerson)
      ..writeByte(11)
      ..write(obj.quoteText)
      ..writeByte(12)
      ..write(obj.imageIndex)
      ..writeByte(13)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotivationItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}


// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardModelAdapter extends TypeAdapter<CardModel> {
  @override
  final int typeId = 26;

  @override
  CardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardModel(
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
      acquisitionCount: fields[14] as int,
      acquisitionHistory: (fields[15] as List).cast<DateTime>(),
      unlockTargetId: fields[16] as String?,
      rarity: fields[17] as String? ?? 'common',
      isStarter: fields[18] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, CardModel obj) {
    writer
      ..writeByte(19)
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
      ..write(obj.metadata)
      ..writeByte(14)
      ..write(obj.acquisitionCount)
      ..writeByte(15)
      ..write(obj.acquisitionHistory)
      ..writeByte(16)
      ..write(obj.unlockTargetId)
      ..writeByte(17)
      ..write(obj.rarity)
      ..writeByte(18)
      ..write(obj.isStarter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

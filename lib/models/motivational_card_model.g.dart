// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motivational_card_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MotivationalCardModelAdapter extends TypeAdapter<MotivationalCardModel> {
  @override
  final int typeId = 23;

  @override
  MotivationalCardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotivationalCardModel(
      id: fields[0] as String,
      text: fields[1] as String,
      imagePath: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MotivationalCardModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotivationalCardModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

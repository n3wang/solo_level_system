// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RewardModelAdapter extends TypeAdapter<RewardModel> {
  @override
  final int typeId = 22;

  @override
  RewardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RewardModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      pointsCost: fields[3] as int,
      category: fields[4] as String,
      iconName: fields[5] as String?,
      color: fields[6] as String?,
      isActive: fields[7] as bool,
      isCustom: fields[8] as bool,
      createdAt: fields[9] as DateTime,
      purchasedAt: fields[10] as DateTime?,
      timesPurchased: fields[11] as int,
      isRecurring: fields[12] as bool,
      maxPurchases: fields[13] as int?,
      metadata: (fields[14] as Map).cast<String, dynamic>(),
      tags: (fields[15] as List).cast<String>(),
      priority: fields[16] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RewardModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.pointsCost)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.iconName)
      ..writeByte(6)
      ..write(obj.color)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.isCustom)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.purchasedAt)
      ..writeByte(11)
      ..write(obj.timesPurchased)
      ..writeByte(12)
      ..write(obj.isRecurring)
      ..writeByte(13)
      ..write(obj.maxPurchases)
      ..writeByte(14)
      ..write(obj.metadata)
      ..writeByte(15)
      ..write(obj.tags)
      ..writeByte(16)
      ..write(obj.priority);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

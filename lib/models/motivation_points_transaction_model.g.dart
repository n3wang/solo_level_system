// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motivation_points_transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MotivationPointsTransactionModelAdapter
    extends TypeAdapter<MotivationPointsTransactionModel> {
  @override
  final int typeId = 27;

  @override
  MotivationPointsTransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotivationPointsTransactionModel(
      id: fields[0] as String,
      kind: fields[1] as String,
      amount: fields[2] as int,
      source: fields[3] as String,
      createdAt: fields[4] as DateTime,
      metadata: (fields[5] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MotivationPointsTransactionModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kind)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotivationPointsTransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

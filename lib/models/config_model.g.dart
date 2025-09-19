// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConfigModelAdapter extends TypeAdapter<ConfigModel> {
  @override
  final int typeId = 9;

  @override
  ConfigModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConfigModel(
      playAudioOnRepeat: fields[0] as bool,
      randomizeAudio: fields[1] as bool,
      showPhotoButton: fields[2] as bool,
      showAudioRecordButton: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ConfigModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.playAudioOnRepeat)
      ..writeByte(1)
      ..write(obj.randomizeAudio)
      ..writeByte(2)
      ..write(obj.showPhotoButton)
      ..writeByte(3)
      ..write(obj.showAudioRecordButton);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

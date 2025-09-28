// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsModelAdapter extends TypeAdapter<UserSettingsModel> {
  @override
  final int typeId = 1;

  @override
  UserSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettingsModel(
      theme: fields[0] as String,
      primaryColor: fields[1] as String,
      defaultWorkMinutes: fields[2] as int,
      defaultBreakMinutes: fields[3] as int,
      autoStartBreaks: fields[4] as bool,
      autoStartWork: fields[5] as bool,
      enableNotifications: fields[6] as bool,
      enableSounds: fields[7] as bool,
      notificationSound: fields[8] as String,
      audioQuality: fields[9] as String,
      audioFormat: fields[10] as String,
      defaultAudioPath: fields[11] as String,
      enableNoiseReduction: fields[12] as bool,
      playAudioDuringWork: fields[19] as bool,
      playAudioDuringBreaks: fields[20] as bool,
      language: fields[13] as String,
      dateFormat: fields[14] as String,
      timeFormat: fields[15] as String,
      enableAnalytics: fields[16] as bool,
      autoBackup: fields[17] as bool,
      backupPath: fields[18] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettingsModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.theme)
      ..writeByte(1)
      ..write(obj.primaryColor)
      ..writeByte(2)
      ..write(obj.defaultWorkMinutes)
      ..writeByte(3)
      ..write(obj.defaultBreakMinutes)
      ..writeByte(4)
      ..write(obj.autoStartBreaks)
      ..writeByte(5)
      ..write(obj.autoStartWork)
      ..writeByte(6)
      ..write(obj.enableNotifications)
      ..writeByte(7)
      ..write(obj.enableSounds)
      ..writeByte(8)
      ..write(obj.notificationSound)
      ..writeByte(9)
      ..write(obj.audioQuality)
      ..writeByte(10)
      ..write(obj.audioFormat)
      ..writeByte(11)
      ..write(obj.defaultAudioPath)
      ..writeByte(12)
      ..write(obj.enableNoiseReduction)
      ..writeByte(19)
      ..write(obj.playAudioDuringWork)
      ..writeByte(20)
      ..write(obj.playAudioDuringBreaks)
      ..writeByte(13)
      ..write(obj.language)
      ..writeByte(14)
      ..write(obj.dateFormat)
      ..writeByte(15)
      ..write(obj.timeFormat)
      ..writeByte(16)
      ..write(obj.enableAnalytics)
      ..writeByte(17)
      ..write(obj.autoBackup)
      ..writeByte(18)
      ..write(obj.backupPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

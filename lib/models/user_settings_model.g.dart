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
      colorPalette: fields[21] as String? ?? 'pastel',
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
      playAudioDuringWork: fields[19] as bool? ?? true,
      playAudioDuringBreaks: fields[20] as bool? ?? false,
      language: fields[13] as String,
      dateFormat: fields[14] as String,
      timeFormat: fields[15] as String,
      enableAnalytics: fields[16] as bool,
      autoBackup: fields[17] as bool,
      backupPath: fields[18] as String,
      developmentDataEnabled: fields[22] as bool? ?? true,
      autoOpenJournalAfterFocus: fields[23] as bool? ?? true,
      cardAcquisitionMode:
          fields[24] as String? ?? 'session_completion',
      sessionCompletionCardCount: fields[25] as int? ?? 1,
      cardAcquireTiming: fields[26] as String? ?? 'after_break',
      rogueChallengeList: (fields[27] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          List<String>.from(RogueChallengeDefaults.base),
    );
  }

  @override
  void write(BinaryWriter writer, UserSettingsModel obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.theme)
      ..writeByte(1)
      ..write(obj.primaryColor)
      ..writeByte(21)
      ..write(obj.colorPalette)
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
      ..write(obj.backupPath)
      ..writeByte(22)
      ..write(obj.developmentDataEnabled)
      ..writeByte(23)
      ..write(obj.autoOpenJournalAfterFocus)
      ..writeByte(24)
      ..write(obj.cardAcquisitionMode)
      ..writeByte(25)
      ..write(obj.sessionCompletionCardCount)
      ..writeByte(26)
      ..write(obj.cardAcquireTiming)
      ..writeByte(27)
      ..write(obj.rogueChallengeList);
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

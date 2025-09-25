// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProgressModelAdapter extends TypeAdapter<UserProgressModel> {
  @override
  final int typeId = 21;

  @override
  UserProgressModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgressModel(
      totalExperience: fields[0] as int,
      availablePoints: fields[1] as int,
      totalPointsEarned: fields[2] as int,
      totalPointsSpent: fields[3] as int,
      currentLevel: fields[4] as int,
      totalPomodoroSessions: fields[5] as int,
      lastSessionDate: fields[6] as DateTime?,
      currentStreak: fields[7] as int,
      longestStreak: fields[8] as int,
      dailySessionCount: (fields[9] as Map).cast<String, int>(),
      weeklyStats: (fields[10] as Map).cast<String, int>(),
      unlockedFeatures: (fields[11] as List).cast<String>(),
      milestoneProgress: (fields[12] as Map).cast<String, int>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserProgressModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.totalExperience)
      ..writeByte(1)
      ..write(obj.availablePoints)
      ..writeByte(2)
      ..write(obj.totalPointsEarned)
      ..writeByte(3)
      ..write(obj.totalPointsSpent)
      ..writeByte(4)
      ..write(obj.currentLevel)
      ..writeByte(5)
      ..write(obj.totalPomodoroSessions)
      ..writeByte(6)
      ..write(obj.lastSessionDate)
      ..writeByte(7)
      ..write(obj.currentStreak)
      ..writeByte(8)
      ..write(obj.longestStreak)
      ..writeByte(9)
      ..write(obj.dailySessionCount)
      ..writeByte(10)
      ..write(obj.weeklyStats)
      ..writeByte(11)
      ..write(obj.unlockedFeatures)
      ..writeByte(12)
      ..write(obj.milestoneProgress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProgressModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

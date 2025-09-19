// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enhanced_audio_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EnhancedAudioModelAdapter extends TypeAdapter<EnhancedAudioModel> {
  @override
  final int typeId = 3;

  @override
  EnhancedAudioModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnhancedAudioModel(
      filePath: fields[0] as String,
      fileName: fields[1] as String,
      createdAt: fields[2] as DateTime,
      modifiedAt: fields[3] as DateTime?,
      durationMs: fields[4] as int,
      fileSizeBytes: fields[5] as int,
      format: fields[6] as String,
      bitRate: fields[7] as int,
      sampleRate: fields[8] as int,
      channels: fields[9] as int,
      title: fields[10] as String?,
      description: fields[11] as String?,
      tags: (fields[12] as List).cast<String>(),
      category: fields[13] as String?,
      rating: fields[14] as int,
      transcription: fields[15] as String?,
      waveformData: (fields[16] as List?)?.cast<double>(),
      waveformSamples: fields[17] as int?,
      processingHistory: (fields[18] as List).cast<String>(),
      originalFilePath: fields[19] as String?,
      playCount: fields[20] as int,
      lastPlayedAt: fields[21] as DateTime?,
      lastPlayPosition: fields[22] as int?,
      isShared: fields[23] as bool,
      sharedWith: (fields[24] as List).cast<String>(),
      isFavorite: fields[25] as bool,
      isArchived: fields[26] as bool,
      averageVolume: fields[27] as double?,
      peakVolume: fields[28] as double?,
      hasSilence: fields[29] as bool?,
      frequencySpectrum: (fields[30] as List?)?.cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, EnhancedAudioModel obj) {
    writer
      ..writeByte(31)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.modifiedAt)
      ..writeByte(4)
      ..write(obj.durationMs)
      ..writeByte(5)
      ..write(obj.fileSizeBytes)
      ..writeByte(6)
      ..write(obj.format)
      ..writeByte(7)
      ..write(obj.bitRate)
      ..writeByte(8)
      ..write(obj.sampleRate)
      ..writeByte(9)
      ..write(obj.channels)
      ..writeByte(10)
      ..write(obj.title)
      ..writeByte(11)
      ..write(obj.description)
      ..writeByte(12)
      ..write(obj.tags)
      ..writeByte(13)
      ..write(obj.category)
      ..writeByte(14)
      ..write(obj.rating)
      ..writeByte(15)
      ..write(obj.transcription)
      ..writeByte(16)
      ..write(obj.waveformData)
      ..writeByte(17)
      ..write(obj.waveformSamples)
      ..writeByte(18)
      ..write(obj.processingHistory)
      ..writeByte(19)
      ..write(obj.originalFilePath)
      ..writeByte(20)
      ..write(obj.playCount)
      ..writeByte(21)
      ..write(obj.lastPlayedAt)
      ..writeByte(22)
      ..write(obj.lastPlayPosition)
      ..writeByte(23)
      ..write(obj.isShared)
      ..writeByte(24)
      ..write(obj.sharedWith)
      ..writeByte(25)
      ..write(obj.isFavorite)
      ..writeByte(26)
      ..write(obj.isArchived)
      ..writeByte(27)
      ..write(obj.averageVolume)
      ..writeByte(28)
      ..write(obj.peakVolume)
      ..writeByte(29)
      ..write(obj.hasSilence)
      ..writeByte(30)
      ..write(obj.frequencySpectrum);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnhancedAudioModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

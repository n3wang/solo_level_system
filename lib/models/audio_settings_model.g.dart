// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioSettingsModelAdapter extends TypeAdapter<AudioSettingsModel> {
  @override
  final int typeId = 2;

  @override
  AudioSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioSettingsModel(
      codec: fields[0] as String,
      bitRate: fields[1] as int,
      sampleRate: fields[2] as int,
      channels: fields[3] as int,
      playbackSpeed: fields[4] as double,
      volume: fields[5] as double,
      enableEqualizer: fields[6] as bool,
      equalizerBands: (fields[7] as List).cast<double>(),
      enableNoiseReduction: fields[8] as bool,
      noiseReductionLevel: fields[9] as double,
      enableAutoGain: fields[10] as bool,
      gainLevel: fields[11] as double,
      enableCompression: fields[12] as bool,
      compressionRatio: fields[13] as double,
      showWaveform: fields[14] as bool,
      waveformColor: fields[15] as String,
      showSpectrogram: fields[16] as bool,
      fftSize: fields[17] as int,
      exportFormat: fields[18] as String,
      exportQuality: fields[19] as int,
      includeMetadata: fields[20] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AudioSettingsModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.codec)
      ..writeByte(1)
      ..write(obj.bitRate)
      ..writeByte(2)
      ..write(obj.sampleRate)
      ..writeByte(3)
      ..write(obj.channels)
      ..writeByte(4)
      ..write(obj.playbackSpeed)
      ..writeByte(5)
      ..write(obj.volume)
      ..writeByte(6)
      ..write(obj.enableEqualizer)
      ..writeByte(7)
      ..write(obj.equalizerBands)
      ..writeByte(8)
      ..write(obj.enableNoiseReduction)
      ..writeByte(9)
      ..write(obj.noiseReductionLevel)
      ..writeByte(10)
      ..write(obj.enableAutoGain)
      ..writeByte(11)
      ..write(obj.gainLevel)
      ..writeByte(12)
      ..write(obj.enableCompression)
      ..writeByte(13)
      ..write(obj.compressionRatio)
      ..writeByte(14)
      ..write(obj.showWaveform)
      ..writeByte(15)
      ..write(obj.waveformColor)
      ..writeByte(16)
      ..write(obj.showSpectrogram)
      ..writeByte(17)
      ..write(obj.fftSize)
      ..writeByte(18)
      ..write(obj.exportFormat)
      ..writeByte(19)
      ..write(obj.exportQuality)
      ..writeByte(20)
      ..write(obj.includeMetadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

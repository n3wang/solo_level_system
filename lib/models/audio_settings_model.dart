// lib/models/audio_settings_model.dart
import 'package:hive/hive.dart';
part 'audio_settings_model.g.dart';

@HiveType(typeId: 2)
class AudioSettingsModel extends HiveObject {
  // Recording Settings
  @HiveField(0)
  String codec; // 'aacLc', 'opus', 'wav'

  @HiveField(1)
  int bitRate; // 64, 128, 256 kbps

  @HiveField(2)
  int sampleRate; // 44100, 48000 Hz

  @HiveField(3)
  int channels; // 1 (mono), 2 (stereo)

  // Playback Settings
  @HiveField(4)
  double playbackSpeed; // 0.5x to 2.0x

  @HiveField(5)
  double volume; // 0.0 to 1.0

  @HiveField(6)
  bool enableEqualizer;

  @HiveField(7)
  List<double> equalizerBands; // 10-band EQ values

  // Processing Settings
  @HiveField(8)
  bool enableNoiseReduction;

  @HiveField(9)
  double noiseReductionLevel; // 0.0 to 1.0

  @HiveField(10)
  bool enableAutoGain;

  @HiveField(11)
  double gainLevel; // -20.0 to +20.0 dB

  @HiveField(12)
  bool enableCompression;

  @HiveField(13)
  double compressionRatio; // 1.0 to 10.0

  // Visualization Settings
  @HiveField(14)
  bool showWaveform;

  @HiveField(15)
  String waveformColor; // hex color

  @HiveField(16)
  bool showSpectrogram;

  @HiveField(17)
  int fftSize; // 256, 512, 1024, 2048

  // Export Settings
  @HiveField(18)
  String exportFormat; // 'mp3', 'wav', 'm4a', 'ogg'

  @HiveField(19)
  int exportQuality; // 0-100

  @HiveField(20)
  bool includeMetadata;

  AudioSettingsModel({
    this.codec = 'aacLc',
    this.bitRate = 128,
    this.sampleRate = 44100,
    this.channels = 1,
    this.playbackSpeed = 1.0,
    this.volume = 0.8,
    this.enableEqualizer = false,
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.enableNoiseReduction = false,
    this.noiseReductionLevel = 0.5,
    this.enableAutoGain = false,
    this.gainLevel = 0.0,
    this.enableCompression = false,
    this.compressionRatio = 2.0,
    this.showWaveform = true,
    this.waveformColor = '#2196F3',
    this.showSpectrogram = false,
    this.fftSize = 512,
    this.exportFormat = 'm4a',
    this.exportQuality = 80,
    this.includeMetadata = true,
  });

  // Convenience getters
  String get qualityDescription {
    if (bitRate >= 256) return 'High Quality';
    if (bitRate >= 128) return 'Medium Quality';
    return 'Low Quality';
  }

  String get playbackSpeedText => '${playbackSpeed}x';

  bool get isStereo => channels == 2;
  bool get isMono => channels == 1;

  // Validate settings
  bool get isValidBitRate => bitRate >= 32 && bitRate <= 320;
  bool get isValidSampleRate => [8000, 16000, 22050, 44100, 48000].contains(sampleRate);
  bool get isValidPlaybackSpeed => playbackSpeed >= 0.25 && playbackSpeed <= 3.0;
}

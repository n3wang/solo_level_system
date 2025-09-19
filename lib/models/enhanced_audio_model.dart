// lib/models/enhanced_audio_model.dart
import 'package:hive/hive.dart';
part 'enhanced_audio_model.g.dart';

@HiveType(typeId: 3)
class EnhancedAudioModel extends HiveObject {
  @HiveField(0)
  String filePath;

  @HiveField(1)
  String fileName;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime? modifiedAt;

  @HiveField(4)
  int durationMs; // Duration in milliseconds

  @HiveField(5)
  int fileSizeBytes;

  @HiveField(6)
  String format; // 'm4a', 'mp3', 'wav', etc.

  @HiveField(7)
  int bitRate;

  @HiveField(8)
  int sampleRate;

  @HiveField(9)
  int channels;

  // Metadata & Organization
  @HiveField(10)
  String? title;

  @HiveField(11)
  String? description;

  @HiveField(12)
  List<String> tags;

  @HiveField(13)
  String? category; // 'voice_note', 'music', 'meeting', 'ambient'

  @HiveField(14)
  int rating; // 1-5 stars

  @HiveField(15)
  String? transcription; // Auto-generated or manual transcription

  // Waveform Data
  @HiveField(16)
  List<double>? waveformData; // Amplitude values for visualization

  @HiveField(17)
  int? waveformSamples; // Number of samples in waveform

  // Processing History
  @HiveField(18)
  List<String> processingHistory; // List of applied effects/edits

  @HiveField(19)
  String? originalFilePath; // Path to original before edits

  // Playback Statistics
  @HiveField(20)
  int playCount;

  @HiveField(21)
  DateTime? lastPlayedAt;

  @HiveField(22)
  int? lastPlayPosition; // Resume position in milliseconds

  // Sharing & Export
  @HiveField(23)
  bool isShared;

  @HiveField(24)
  List<String> sharedWith; // User IDs or emails

  @HiveField(25)
  bool isFavorite;

  @HiveField(26)
  bool isArchived;

  // Analysis Data
  @HiveField(27)
  double? averageVolume; // RMS volume level

  @HiveField(28)
  double? peakVolume; // Peak volume level

  @HiveField(29)
  bool? hasSilence; // Contains periods of silence

  @HiveField(30)
  List<double>? frequencySpectrum; // Frequency analysis data

  EnhancedAudioModel({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    this.modifiedAt,
    required this.durationMs,
    required this.fileSizeBytes,
    required this.format,
    required this.bitRate,
    required this.sampleRate,
    required this.channels,
    this.title,
    this.description,
    this.tags = const [],
    this.category,
    this.rating = 0,
    this.transcription,
    this.waveformData,
    this.waveformSamples,
    this.processingHistory = const [],
    this.originalFilePath,
    this.playCount = 0,
    this.lastPlayedAt,
    this.lastPlayPosition,
    this.isShared = false,
    this.sharedWith = const [],
    this.isFavorite = false,
    this.isArchived = false,
    this.averageVolume,
    this.peakVolume,
    this.hasSilence,
    this.frequencySpectrum,
  });

  // Convenience getters
  String get durationFormatted {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get qualityDescription {
    if (bitRate >= 256) return 'High Quality';
    if (bitRate >= 128) return 'Medium Quality';
    return 'Low Quality';
  }

  bool get hasWaveform => waveformData != null && waveformData!.isNotEmpty;
  bool get hasTranscription => transcription != null && transcription!.isNotEmpty;
  bool get isEdited => processingHistory.isNotEmpty;
  bool get hasBeenPlayed => playCount > 0;

  // Methods for managing audio
  void incrementPlayCount() {
    playCount++;
    lastPlayedAt = DateTime.now();
    save();
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      save();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    save();
  }

  void addProcessingStep(String step) {
    processingHistory.add(step);
    modifiedAt = DateTime.now();
    save();
  }

  void toggleFavorite() {
    isFavorite = !isFavorite;
    save();
  }

  void archive() {
    isArchived = true;
    save();
  }

  void unarchive() {
    isArchived = false;
    save();
  }
}

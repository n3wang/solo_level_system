import 'package:audioplayers/audioplayers.dart';

enum SoundEvent {
  audioRecordSubmitted, // s01 - when audio record is submitted
  breakTimeStarts,      // s01 - when break time starts
  workTimeCompleted,    // s03 - when work time is completed
  breakTimeEnds,        // s02 - when break time ends
}

class SoundEffectsService {
  static final SoundEffectsService _instance = SoundEffectsService._internal();
  factory SoundEffectsService() => _instance;
  SoundEffectsService._internal();

  final AudioPlayer _soundPlayer = AudioPlayer();
  bool _soundEffectsEnabled = true;
  double _soundVolume = 0.8;

  // Sound file mappings
  static const Map<SoundEvent, String> _soundFiles = {
    SoundEvent.audioRecordSubmitted: 'audio/s01-video-game-bonus-323603.mp3',
    SoundEvent.breakTimeStarts: 'audio/s01-video-game-bonus-323603.mp3',
    SoundEvent.workTimeCompleted: 'audio/s03-positive-notification-new-level-152480.mp3',
    SoundEvent.breakTimeEnds: 'audio/s02-level-up-4-243762.mp3',
  };

  bool get soundEffectsEnabled => _soundEffectsEnabled;
  double get soundVolume => _soundVolume;

  void setSoundEffectsEnabled(bool enabled) {
    _soundEffectsEnabled = enabled;
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
  }

  Future<void> playSound(SoundEvent event) async {
    if (!_soundEffectsEnabled) return;

    try {
      final soundFile = _soundFiles[event];
      if (soundFile == null) {
        print('No sound file mapped for event: $event');
        return;
      }

      await _soundPlayer.stop();
      await _soundPlayer.setVolume(_soundVolume);
      await _soundPlayer.play(AssetSource(soundFile));

      print('Playing sound for event: $event');
    } catch (e) {
      print('Failed to play sound for event $event: $e');
    }
  }

  Future<void> playAudioRecordSubmitted() async {
    await playSound(SoundEvent.audioRecordSubmitted);
  }

  Future<void> playBreakTimeStarts() async {
    await playSound(SoundEvent.breakTimeStarts);
  }

  Future<void> playWorkTimeCompleted() async {
    await playSound(SoundEvent.workTimeCompleted);
  }

  Future<void> playBreakTimeEnds() async {
    await playSound(SoundEvent.breakTimeEnds);
  }

  void dispose() {
    _soundPlayer.dispose();
  }
}
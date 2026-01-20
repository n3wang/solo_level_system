// lib/utils/exercise_audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Service for finding and playing exercise audio files
class ExerciseAudioService {
  static final ExerciseAudioService _instance = ExerciseAudioService._internal();
  factory ExerciseAudioService() => _instance;
  ExerciseAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _audioBasePath = 'audio/workouts';

  /// Get the audio file path from an exercise's audioFile field
  /// Returns the full path to the audio file if it exists
  Future<String?> getExerciseAudioPath(String? audioFile) async {
    print('[AudioService] getExerciseAudioPath called with: $audioFile');
    
    if (audioFile == null || audioFile.isEmpty) {
      print('[AudioService] audioFile is null or empty');
      return null;
    }

    print('[AudioService] Processing audioFile from model: "$audioFile"');

    // If audioFile already includes the path, use it as is
    if (audioFile.startsWith('audio/')) {
      final audioPath = audioFile.endsWith('.mp3') ? audioFile : '$audioFile.mp3';
      print('[AudioService] audioFile starts with "audio/", checking path: $audioPath');
      try {
        await rootBundle.load(audioPath);
        print('[AudioService] ✓ Audio file FOUND at: $audioPath');
        return audioPath;
      } catch (e) {
        print('[AudioService] ✗ Audio file NOT FOUND at: $audioPath');
        print('[AudioService] Error: $e');
        return null;
      }
    }

    // Otherwise, assume it's in the workouts folder
    final audioPath = '$_audioBasePath/$audioFile';
    final finalPath = audioPath.endsWith('.mp3') ? audioPath : '$audioPath.mp3';
    print('[AudioService] audioFile does not start with "audio/", constructing path: $finalPath');
    
    try {
      await rootBundle.load(finalPath);
      print('[AudioService] ✓ Audio file FOUND at: $finalPath');
      return finalPath;
    } catch (e) {
      print('[AudioService] ✗ Audio file NOT FOUND at: $finalPath');
      print('[AudioService] Error: $e');
      return null;
    }
  }


  /// Play exercise audio using the audioFile from ExerciseModel
  Future<void> playExerciseAudio(String? audioFile) async {
    print('[AudioService] playExerciseAudio called with audioFile from model: "$audioFile"');
    
    if (audioFile == null || audioFile.isEmpty) {
      print('[AudioService] ✗ Cannot play audio: audioFile is null or empty');
      return;
    }

    print('[AudioService] Resolving audio file path...');
    final audioPath = await getExerciseAudioPath(audioFile);
    
    if (audioPath == null) {
      print('[AudioService] ✗ Cannot play audio: file not found for "$audioFile"');
      print('[AudioService] Original audioFile from model was: "$audioFile"');
      return;
    }

    print('[AudioService] ✓ Resolved path: "$audioPath"');
    print('[AudioService] Attempting to play audio from: "$audioPath"');

    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();
      // Set volume to ensure audio plays
      await _audioPlayer.setVolume(1.0);
      // Play the audio
      await _audioPlayer.play(AssetSource(audioPath));
      print('[AudioService] ✓ Successfully started playing audio: "$audioPath"');
    } catch (e) {
      print('[AudioService] ✗ Failed to play exercise audio at "$audioPath"');
      print('[AudioService] Error type: ${e.runtimeType}');
      print('[AudioService] Error details: $e');
    }
  }

  /// Play a break sound effect
  Future<void> playBreakSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/break_time.mp3'));
      print('Playing break sound');
    } catch (e) {
      print('Failed to play break sound: $e');
    }
  }

  /// Play countdown audio for a specific number (1-5)
  Future<void> playCountdown(int number) async {
    if (number < 1 || number > 5) {
      print('Invalid countdown number: $number (must be 1-5)');
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/$number.mp3'));
      print('Playing countdown: $number');
    } catch (e) {
      print('Failed to play countdown $number: $e');
    }
  }

  /// Play "5 seconds left" audio
  Future<void> play5SecondsLeft() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/5_seconds_left.mp3'));
      print('Playing 5 seconds left warning');
    } catch (e) {
      print('Failed to play 5 seconds left sound: $e');
    }
  }

  /// Play workout complete audio
  Future<void> playWorkoutComplete() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/workout_complete.mp3'));
      print('Playing workout complete sound');
    } catch (e) {
      print('Failed to play workout complete sound: $e');
    }
  }

  /// Stop any currently playing audio
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Failed to stop audio: $e');
    }
  }

  /// Dispose the audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}

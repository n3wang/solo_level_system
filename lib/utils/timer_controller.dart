import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/sound_effects_service.dart';
import 'package:solo_level_system/utils/notification_service.dart';

class TimerController {
  static final TimerController _instance = TimerController._internal();
  factory TimerController() => _instance;
  TimerController._internal();

  // Timer state
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _remainingSeconds = 1500;
  bool _isRunning = false;
  bool _onBreak = false;
  bool _allowMusic = true;
  Timer? _timer;
  DateTime? _sessionStartTime;

  // Services
  final _backgroundMusicService = BackgroundMusicService();
  final _soundEffectsService = SoundEffectsService();
  final _notificationService = NotificationService();

  // Listeners for UI updates
  final List<VoidCallback> _listeners = [];

  // Getters
  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get onBreak => _onBreak;
  bool get allowMusic => _allowMusic;
  DateTime? get sessionStartTime => _sessionStartTime;

  // Add listener for UI updates
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // Initialize services
  Future<void> initialize() async {
    await _backgroundMusicService.initialize();
    await _notificationService.initialize();
  }

  // Update timer durations
  void updateDurations(int workMin, int breakMin) {
    _workMinutes = workMin;
    _breakMinutes = breakMin;
    if (!_isRunning && !_onBreak) {
      _remainingSeconds = _workMinutes * 60;
    }
    _notifyListeners();
  }

  // Start timer
  void startTimer() async {
    if (_allowMusic) {
      await _playLofi();
    }

    _isRunning = true;
    if (!_onBreak) {
      _sessionStartTime = DateTime.now();
    }
    _notifyListeners();

    // Show notification
    _notificationService.showTimerNotification(
      remainingSeconds: _remainingSeconds,
      isRunning: true,
      isBreak: _onBreak,
      onPlay: startTimer,
      onPause: pauseTimer,
      onReset: resetTimer,
      onMute: toggleMute,
    );

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _completeSession();
      } else {
        _remainingSeconds--;
        _notifyListeners();
      }
    });
  }

  // Pause timer
  void pauseTimer() {
    _stopLofi();
    _timer?.cancel();
    _isRunning = false;
    _notifyListeners();
    _notificationService.hideTimerNotification();
  }

  // Reset timer
  void resetTimer() {
    pauseTimer();
    _remainingSeconds = _onBreak ? _breakMinutes * 60 : _workMinutes * 60;
    _sessionStartTime = null;
    _notifyListeners();
  }

  // Toggle mute
  void toggleMute() {
    _allowMusic = !_allowMusic;
    if (_allowMusic && _isRunning) {
      _playLofi();
    } else if (!_allowMusic) {
      _stopLofi();
    }
    _notifyListeners();
  }

  // Complete session
  void _completeSession() {
    _stopLofi();
    _timer?.cancel();

    if (!_onBreak) {
      // Work session finished
      _soundEffectsService.playWorkTimeCompleted();
      _isRunning = false;
      _notificationService.hideTimerNotification();
      _notifyListeners();
    } else {
      // Break finished
      _soundEffectsService.playBreakTimeEnds();
      _onBreak = false;
      _isRunning = false;
      _remainingSeconds = _workMinutes * 60;
      _notificationService.hideTimerNotification();
      _notifyListeners();
    }
  }

  // Start break
  void startBreak() {
    _soundEffectsService.playBreakTimeStarts();
    _onBreak = true;
    _remainingSeconds = _breakMinutes * 60;
    _notifyListeners();
    startTimer();
  }

  // Play background music
  Future<void> _playLofi() async {
    if (_backgroundMusicService.isPlaying) {
      await _backgroundMusicService.stop();
    }
    if (!_allowMusic) return;

    try {
      await _backgroundMusicService.playRandomTrack();
    } catch (e) {
      print('Failed to play lofi music: $e');
    }
  }

  // Stop background music
  void _stopLofi() {
    _backgroundMusicService.stop();
  }

  // Get current track info
  String? getCurrentTrackTitle() {
    final track = _backgroundMusicService.currentTrack;
    return track?.title;
  }

  // Dispose
  void dispose() {
    _timer?.cancel();
    _backgroundMusicService.dispose();
    _soundEffectsService.dispose();
    _notificationService.dispose();
    _listeners.clear();
  }

  // Format time helper
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
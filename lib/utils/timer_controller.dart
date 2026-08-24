import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/sound_effects_service.dart';
import 'package:solo_level_system/utils/notification_service.dart';
import 'package:solo_level_system/services/pomodoro_session_service.dart';
import 'package:solo_level_system/services/solo_sync_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  bool _isStarting = false;
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

  /// Timer is idle (not running) but a work or break countdown is still active
  /// (user paused mid-session). Distinct from completion (remaining 0 / submit log).
  bool get isMidSessionPaused =>
      !_isRunning &&
      _remainingSeconds > 0 &&
      (_sessionStartTime != null || _onBreak);

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
  void startTimer({bool manageMusic = true}) async {
    if (_isRunning || _isStarting) return;
    _isStarting = true;

    // Cancel any existing timer first to prevent multiple timers running
    _timer?.cancel();
    _timer = null;

    // Set running immediately to avoid rapid double-tap creating duplicates.
    _isRunning = true;
    if (!_onBreak) {
      _sessionStartTime = DateTime.now();
      // Best-effort pull of other devices' sessions so today's count/streak
      // reflect them. Fire-and-forget: never blocks starting the timer, and
      // silently no-ops offline/logged-out (see SoloSyncService.syncNow).
      unawaited(SoloSyncService.instance.syncNow());
    }
    _notifyListeners();

    try {
      if (manageMusic && _allowMusic) {
        // Sfx (e.g. break ended) can hold audio focus; wait briefly before lofi.
        await _soundEffectsService.waitUntilIdle();
        if (_backgroundMusicService.currentTrack != null) {
          await _backgroundMusicService.ensurePlaying();
        } else {
          await _playLofi();
        }
      }

      // Keep the system awake for the duration of the session, unless the
      // user opted out in Settings (defaults to on).
      if (!kIsWeb && PomodoroSessionService.liveUserSettings().keepAwakeDuringSession) {
        await WakelockPlus.enable();
      }

      // If paused while async setup was in progress, do not create timer.
      if (!_isRunning) return;

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
    } finally {
      _isStarting = false;
    }
  }

  // Pause timer
  void pauseTimer() async {
    print('[TIMER_CONTROLLER] pauseTimer() called');
    print(
      '[TIMER_CONTROLLER] Before pause - isRunning: $_isRunning, timer: ${_timer != null}',
    );
    // Pause the music instead of stopping it
    if (_backgroundMusicService.isPlaying) {
      await _backgroundMusicService.pause();
    }
    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    // Disable wakelock when timer is paused
    if (!kIsWeb) await WakelockPlus.disable();

    print('[TIMER_CONTROLLER] After pause - isRunning: $_isRunning');
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

  // Set remaining seconds (for instant finish)
  void setRemainingSeconds(int seconds) {
    _remainingSeconds = seconds;
    _notifyListeners();
  }

  // Toggle mute
  void toggleMute() {
    setMusicAllowed(!_allowMusic, resumeIfRunning: true);
  }

  void setMusicAllowed(bool allowed, {bool resumeIfRunning = false}) {
    if (_allowMusic == allowed) return;
    _allowMusic = allowed;
    if (!_allowMusic) {
      _stopLofi();
    } else if (resumeIfRunning && _isRunning) {
      _resumeMusicIfRunning();
    }
    _notifyListeners();
  }

  void _resumeMusicIfRunning() {
    if (!_allowMusic || !_isRunning) return;
    if (_backgroundMusicService.currentTrack != null &&
        !_backgroundMusicService.isPlaying) {
      _backgroundMusicService.ensurePlaying();
    } else if (_backgroundMusicService.currentTrack == null) {
      _playLofi();
    }
  }

  // Complete session
  void _completeSession() async {
    _stopLofi();
    _timer?.cancel();

    // Disable wakelock when session completes
    if (!kIsWeb) await WakelockPlus.disable();

    if (!_onBreak) {
      // Work session finished
      _soundEffectsService.playWorkTimeCompleted();
      _isRunning = false;
      _remainingSeconds = 0; // Keep at 0 to show completion
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

  /// Move into break with full break duration, paused (does not start ticking).
  void prepareBreakPaused() {
    _timer?.cancel();
    _timer = null;
    _soundEffectsService.playBreakTimeStarts();
    _onBreak = true;
    _isRunning = false;
    _remainingSeconds = _breakMinutes * 60;
    _notificationService.hideTimerNotification();
    _notifyListeners();
  }

  /// Resume a break that was prepared paused after a focus session.
  void resumePausedBreak() {
    if (!_onBreak) {
      startBreak();
      return;
    }
    if (_isRunning) return;
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
  void dispose() async {
    _timer?.cancel();
    if (!kIsWeb) await WakelockPlus.disable();
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

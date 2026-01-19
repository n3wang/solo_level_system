import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solo_level_system/utils/timer_controller.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _hasActiveTimer = false;
  Timer? _updateTimer;
  int _remainingSeconds = 0;
  bool _isBreak = false;
  bool _isRunning = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request notification permission on Android 13+
    await _requestNotificationPermission();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;

      if (status.isDenied) {
        final result = await Permission.notification.request();
        if (result.isDenied) {
          print('Notification permission denied');
        }
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
    }
  }

  void _onNotificationTap(NotificationResponse notificationResponse) {
    final String? actionId = notificationResponse.actionId;
    final timerController = TimerController();

    switch (actionId) {
      case 'play':
        timerController.startTimer();
        break;
      case 'pause':
        timerController.pauseTimer();
        break;
      case 'reset':
        timerController.resetTimer();
        break;
      case 'mute':
        timerController.toggleMute();
        break;
      default:
        // Handle regular notification tap (open app)
        break;
    }
  }

  Future<void> showTimerNotification({
    required int remainingSeconds,
    required bool isRunning,
    required bool isBreak,
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onReset,
    VoidCallback? onMute,
  }) async {
    if (!_isInitialized) await initialize();

    _remainingSeconds = remainingSeconds;
    _isBreak = isBreak;
    _isRunning = isRunning;

    final String timeText = formatTime(remainingSeconds);
    final String status = isBreak ? 'Break' : 'Focus';
    final String title = isRunning
        ? '$status Time - $timeText'
        : '$status Time - Paused';

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'pomodoro_timer',
          'Pomodoro Timer',
          channelDescription: 'Notification for pomodoro timer controls',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          category: AndroidNotificationCategory.stopwatch,
          actions: _buildNotificationActions(isRunning),
          icon: '@mipmap/launcher_icon',
        );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _notifications.show(1, title, 'Tap to open app', notificationDetails);

    if (isRunning && !_hasActiveTimer) {
      _startUpdateTimer();
    } else if (!isRunning && _hasActiveTimer) {
      _stopUpdateTimer();
    }
  }

  List<AndroidNotificationAction> _buildNotificationActions(bool isRunning) {
    return [
      if (isRunning)
        const AndroidNotificationAction(
          'pause',
          'Pause',
          cancelNotification: false,
          showsUserInterface: false,
        )
      else
        const AndroidNotificationAction(
          'reset',
          'Reset',
          cancelNotification: false,
          showsUserInterface: false,
        ),
      const AndroidNotificationAction(
        'mute',
        'Mute',
        cancelNotification: false,
        showsUserInterface: false,
      ),
    ];
  }

  void _startUpdateTimer() {
    _hasActiveTimer = true;
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _updateNotificationTime();
      } else {
        _stopUpdateTimer();
      }
    });
  }

  void _stopUpdateTimer() {
    _hasActiveTimer = false;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _updateNotificationTime() {
    final String timeText = formatTime(_remainingSeconds);
    final String status = _isBreak ? 'Break' : 'Focus';
    final String title = '$status Time - $timeText';

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'pomodoro_timer',
          'Pomodoro Timer',
          channelDescription: 'Notification for pomodoro timer controls',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          category: AndroidNotificationCategory.stopwatch,
          actions: _buildNotificationActions(_isRunning),
          icon: '@mipmap/launcher_icon',
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    _notifications.show(1, title, 'Tap to open app', notificationDetails);
  }

  Future<void> hideTimerNotification() async {
    _stopUpdateTimer();
    await _notifications.cancel(1);
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _stopUpdateTimer();
    hideTimerNotification();
  }
}

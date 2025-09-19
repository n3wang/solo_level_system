// lib/models/user_settings_model.dart
import 'package:hive/hive.dart';
part 'user_settings_model.g.dart';

@HiveType(typeId: 1)
class UserSettingsModel extends HiveObject {
  // Theme & Appearance
  @HiveField(0)
  String theme; // 'light', 'dark', 'system'

  @HiveField(1)
  String primaryColor; // 'red', 'blue', 'green', etc.

  // Session Settings
  @HiveField(2)
  int defaultWorkMinutes;

  @HiveField(3)
  int defaultBreakMinutes;

  @HiveField(4)
  bool autoStartBreaks;

  @HiveField(5)
  bool autoStartWork;

  // Notification Settings
  @HiveField(6)
  bool enableNotifications;

  @HiveField(7)
  bool enableSounds;

  @HiveField(8)
  String notificationSound; // path to custom sound or built-in name

  // Audio Settings
  @HiveField(9)
  String audioQuality; // 'low', 'medium', 'high'

  @HiveField(10)
  String audioFormat; // 'm4a', 'mp3', 'wav'

  @HiveField(11)
  String defaultAudioPath; // custom folder path

  @HiveField(12)
  bool enableNoiseReduction;

  // Language & Localization
  @HiveField(13)
  String language; // 'en', 'es', 'fr', etc.

  @HiveField(14)
  String dateFormat; // 'MM/dd/yyyy', 'dd/MM/yyyy', etc.

  @HiveField(15)
  String timeFormat; // '12h', '24h'

  // Privacy & Data
  @HiveField(16)
  bool enableAnalytics;

  @HiveField(17)
  bool autoBackup;

  @HiveField(18)
  String backupPath;

  UserSettingsModel({
    this.theme = 'system',
    this.primaryColor = 'red',
    this.defaultWorkMinutes = 25,
    this.defaultBreakMinutes = 5,
    this.autoStartBreaks = false,
    this.autoStartWork = false,
    this.enableNotifications = true,
    this.enableSounds = true,
    this.notificationSound = 'default',
    this.audioQuality = 'medium',
    this.audioFormat = 'm4a',
    this.defaultAudioPath = '',
    this.enableNoiseReduction = false,
    this.language = 'en',
    this.dateFormat = 'MM/dd/yyyy',
    this.timeFormat = '12h',
    this.enableAnalytics = false,
    this.autoBackup = true,
    this.backupPath = '',
  });

  // Convenience methods
  bool get isDarkTheme => theme == 'dark';
  bool get isLightTheme => theme == 'light';
  bool get isSystemTheme => theme == 'system';

  // Audio quality as bitrate
  int get audioBitrate {
    switch (audioQuality) {
      case 'low':
        return 64;
      case 'medium':
        return 128;
      case 'high':
        return 256;
      default:
        return 128;
    }
  }
}

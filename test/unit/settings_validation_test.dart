import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';

void main() {
  group('Settings Validation Tests', () {
    setUpAll(() async {
      await setUpTestHive();
      Hive.registerAdapter(UserSettingsModelAdapter());
      Hive.registerAdapter(AudioSettingsModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    test('UserSettingsModel should initialize with default values', () {
      final settings = UserSettingsModel();

      expect(settings.theme, equals('system'));
      expect(settings.primaryColor, equals('red'));
      expect(settings.defaultWorkMinutes, equals(25));
      expect(settings.defaultBreakMinutes, equals(5));
      expect(settings.autoStartBreaks, equals(false));
      expect(settings.autoStartWork, equals(false));
      expect(settings.enableNotifications, equals(true));
      expect(settings.enableSounds, equals(true));
      expect(settings.notificationSound, equals('default'));
    });

    test('UserSettingsModel should save and load from Hive correctly', () async {
      final box = await Hive.openBox<UserSettingsModel>('test_settings');

      final originalSettings = UserSettingsModel(
        theme: 'dark',
        primaryColor: 'blue',
        defaultWorkMinutes: 30,
        enableNotifications: false,
      );

      await box.put('settings', originalSettings);
      final loadedSettings = box.get('settings');

      expect(loadedSettings, isNotNull);
      expect(loadedSettings!.theme, equals('dark'));
      expect(loadedSettings.primaryColor, equals('blue'));
      expect(loadedSettings.defaultWorkMinutes, equals(30));
      expect(loadedSettings.enableNotifications, equals(false));

      await box.close();
    });

    test('AudioSettingsModel should initialize with default values', () {
      final audioSettings = AudioSettingsModel();

      expect(audioSettings.codec, equals('aacLc'));
      expect(audioSettings.bitRate, equals(128));
      expect(audioSettings.sampleRate, equals(44100));
      expect(audioSettings.channels, equals(1));
      expect(audioSettings.playbackSpeed, equals(1.0));
      expect(audioSettings.volume, equals(0.8));
      expect(audioSettings.enableNoiseReduction, equals(false));
    });

    test('AudioSettingsModel validation methods work correctly', () {
      final audioSettings = AudioSettingsModel(
        bitRate: 256,
        sampleRate: 48000,
        playbackSpeed: 1.5,
      );

      expect(audioSettings.isValidBitRate, equals(true));
      expect(audioSettings.isValidSampleRate, equals(true));
      expect(audioSettings.isValidPlaybackSpeed, equals(true));
      expect(audioSettings.qualityDescription, equals('High Quality'));
      expect(audioSettings.playbackSpeedText, equals('1.5x'));
    });

    test('Settings should handle invalid values gracefully', () {
      final settings = UserSettingsModel(
        defaultWorkMinutes: -5, // Invalid value
        defaultBreakMinutes: 100, // Invalid value
      );

      // The model should still accept these values (validation happens in UI)
      expect(settings.defaultWorkMinutes, equals(-5));
      expect(settings.defaultBreakMinutes, equals(100));
    });

    test('Audio settings should validate correctly', () {
      final invalidAudioSettings = AudioSettingsModel(
        bitRate: 10, // Too low
        sampleRate: 1000, // Invalid
        playbackSpeed: 5.0, // Too high
      );

      expect(invalidAudioSettings.isValidBitRate, equals(false));
      expect(invalidAudioSettings.isValidSampleRate, equals(false));
      expect(invalidAudioSettings.isValidPlaybackSpeed, equals(false));
    });

    test('Settings should persist changes correctly', () async {
      final box = await Hive.openBox<UserSettingsModel>('test_persistence');

      // Initial settings
      var settings = UserSettingsModel();
      await box.put('settings', settings);

      // Load and modify
      settings = box.get('settings')!;
      settings.theme = 'dark';
      settings.defaultWorkMinutes = 45;
      await box.put('settings', settings);

      // Reload and verify persistence
      final reloadedSettings = box.get('settings')!;
      expect(reloadedSettings.theme, equals('dark'));
      expect(reloadedSettings.defaultWorkMinutes, equals(45));

      await box.close();
    });

    test('Multiple settings can coexist without interference', () async {
      final userBox = await Hive.openBox<UserSettingsModel>('test_user');
      final audioBox = await Hive.openBox<AudioSettingsModel>('test_audio');

      final userSettings = UserSettingsModel(theme: 'dark');
      final audioSettings = AudioSettingsModel(bitRate: 256);

      await userBox.put('settings', userSettings);
      await audioBox.put('settings', audioSettings);

      final loadedUser = userBox.get('settings')!;
      final loadedAudio = audioBox.get('settings')!;

      expect(loadedUser.theme, equals('dark'));
      expect(loadedAudio.bitRate, equals(256));

      await userBox.close();
      await audioBox.close();
    });
  });
}
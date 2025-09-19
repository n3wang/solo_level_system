import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';

void main() {
  group('Settings Persistence Tests', () {
    setUpAll(() async {
      await setUpTestHive();
      Hive.registerAdapter(UserSettingsModelAdapter());
      Hive.registerAdapter(AudioSettingsModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    testWidgets('UserSettings should persist to Hive', (WidgetTester tester) async {
      final box = await Hive.openBox<UserSettingsModel>('test_userSettings');

      // Create and save settings
      final settings = UserSettingsModel(
        theme: 'dark',
        primaryColor: 'blue',
        defaultWorkMinutes: 30,
        defaultBreakMinutes: 10,
        autoStartBreaks: true,
        enableNotifications: false,
      );

      await box.put('settings', settings);

      // Retrieve and verify
      final retrievedSettings = box.get('settings');
      expect(retrievedSettings, isNotNull);
      expect(retrievedSettings!.theme, equals('dark'));
      expect(retrievedSettings.primaryColor, equals('blue'));
      expect(retrievedSettings.defaultWorkMinutes, equals(30));
      expect(retrievedSettings.defaultBreakMinutes, equals(10));
      expect(retrievedSettings.autoStartBreaks, equals(true));
      expect(retrievedSettings.enableNotifications, equals(false));

      await box.close();
    });

    testWidgets('AudioSettings should persist to Hive', (WidgetTester tester) async {
      final box = await Hive.openBox<AudioSettingsModel>('test_audioSettings');

      // Create and save audio settings
      final audioSettings = AudioSettingsModel(
        codec: 'opus',
        bitRate: 256,
        sampleRate: 48000,
        channels: 2,
        playbackSpeed: 1.5,
        volume: 0.9,
        enableNoiseReduction: true,
      );

      await box.put('settings', audioSettings);

      // Retrieve and verify
      final retrievedSettings = box.get('settings');
      expect(retrievedSettings, isNotNull);
      expect(retrievedSettings!.codec, equals('opus'));
      expect(retrievedSettings.bitRate, equals(256));
      expect(retrievedSettings.sampleRate, equals(48000));
      expect(retrievedSettings.channels, equals(2));
      expect(retrievedSettings.playbackSpeed, equals(1.5));
      expect(retrievedSettings.volume, equals(0.9));
      expect(retrievedSettings.enableNoiseReduction, equals(true));

      await box.close();
    });

    testWidgets('Settings should maintain defaults when not found', (WidgetTester tester) async {
      final box = await Hive.openBox<UserSettingsModel>('test_emptySettings');

      // Try to get non-existent settings
      final settings = box.get('settings') ?? UserSettingsModel();

      // Verify default values
      expect(settings.theme, equals('system'));
      expect(settings.primaryColor, equals('red'));
      expect(settings.defaultWorkMinutes, equals(25));
      expect(settings.defaultBreakMinutes, equals(5));
      expect(settings.autoStartBreaks, equals(false));
      expect(settings.enableNotifications, equals(true));

      await box.close();
    });
  });
}
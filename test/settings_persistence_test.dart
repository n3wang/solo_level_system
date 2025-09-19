import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

void main() {
  group('Settings Persistence Tests', () {
    setUpAll(() async {
      await setUpTestHive();
      Hive.registerAdapter(UserSettingsModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    test('UserSettings should persist basic values', () async {
      final box = await Hive.openBox<UserSettingsModel>('test_userSettings');

      // Create and save settings
      final settings = UserSettingsModel(
        theme: 'dark',
        primaryColor: 'blue',
        defaultWorkMinutes: 30,
        enableNotifications: false,
      );

      await box.put('settings', settings);

      // Retrieve and verify key values only
      final retrieved = box.get('settings');
      expect(retrieved, isNotNull);
      expect(retrieved!.theme, equals('dark'));
      expect(retrieved.primaryColor, equals('blue'));
      expect(retrieved.defaultWorkMinutes, equals(30));

      await box.close();
    });

    test('Settings should use defaults when not found', () async {
      final box = await Hive.openBox<UserSettingsModel>('test_emptySettings');

      final settings = box.get('settings') ?? UserSettingsModel();

      // Verify key defaults
      expect(settings.theme, equals('system'));
      expect(settings.primaryColor, equals('red'));
      expect(settings.defaultWorkMinutes, equals(25));

      await box.close();
    });
  });
}
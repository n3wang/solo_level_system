import 'package:flutter_test/flutter_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

void main() {
  group('Settings Validation Tests', () {
    test('UserSettingsModel should initialize with defaults', () {
      final settings = UserSettingsModel();

      expect(settings.theme, equals('system'));
      expect(settings.primaryColor, equals('green'));
      expect(settings.defaultWorkMinutes, equals(25));
      expect(settings.defaultBreakMinutes, equals(5));
      expect(settings.enableNotifications, equals(true));
    });
  });
}

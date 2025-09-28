import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

void main() {
  group('Audio Settings Tests', () {
    setUp(() async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserSettingsModelAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('UserSettingsModel should have audio control properties', () {
      final settings = UserSettingsModel();

      expect(settings.playAudioDuringWork, isTrue);
      expect(settings.playAudioDuringBreaks, isFalse);
    });

    test('Audio settings should persist correctly', () async {
      final box = await Hive.openBox<UserSettingsModel>('testSettings');

      final settings = UserSettingsModel(
        playAudioDuringWork: false,
        playAudioDuringBreaks: true,
      );

      await box.put('audio_test', settings);
      final retrieved = box.get('audio_test');

      expect(retrieved?.playAudioDuringWork, isFalse);
      expect(retrieved?.playAudioDuringBreaks, isTrue);

      await box.close();
    });

    test('Audio settings should allow customization', () {
      final settings = UserSettingsModel(
        playAudioDuringWork: false,
        playAudioDuringBreaks: true,
      );

      expect(settings.playAudioDuringWork, isFalse);
      expect(settings.playAudioDuringBreaks, isTrue);
    });
  });
}
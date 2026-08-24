import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/services/install_id_service.dart';
import 'package:solo_level_system/services/solo_sync_service.dart';
import 'package:solo_level_system/sync/solo_snapshot.dart';

void main() {
  test('snapshot codec ignores unknown keys and fills defaults', () {
    final settings = SoloSnapshotCodec.settingsFromMap({
      'theme': 'dark',
      'futureFlag': true,
    });
    expect(settings.theme, 'dark');
    expect(settings.defaultWorkMinutes, 25);

    final pomodoro = SoloSnapshotCodec.pomodoroFromMap({
      'clientId': 'abc',
      'startTime': '2026-01-01T00:00:00Z',
      'unknownColumn': 9,
    });
    expect(pomodoro.clientId, 'abc');
    expect(pomodoro.minutesSpent, 25);
  });

  test('logout wipes stats boxes and keeps installId', () async {
    await setUpTestHive();
    Hive.registerAdapter(PomodoroModelAdapter());
    Hive.registerAdapter(UserProgressModelAdapter());
    Hive.registerAdapter(UserSettingsModelAdapter());

    final flags = await Hive.openBox('app_init_flags');
    await flags.put(InstallIdService.key, 'install-keep');
    final pomos = await Hive.openBox<PomodoroModel>('pomodoros');
    await pomos.add(PomodoroModel(startTime: DateTime.now(), clientId: 'x'));
    final progress = await Hive.openBox<UserProgressModel>('userProgress');
    await progress.put(
      'progress',
      UserProgressModel(totalPomodoroSessions: 12),
    );
    await Hive.openBox<UserSettingsModel>('userSettings');

    await SoloSyncService.instance.logoutAndWipeStats();

    expect(pomos.isEmpty, isTrue);
    expect(progress.get('progress')?.totalPomodoroSessions, 0);
    expect(flags.get(InstallIdService.key), 'install-keep');

    await tearDownTestHive();
  });

  test('applySnapshot merges pomodoros instead of clearing local sessions '
      '(multi-device safety: a session from another device must not wipe '
      'out a not-yet-pushed local session)', () async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PomodoroModelAdapter());
    }

    final pomos = await Hive.openBox<PomodoroModel>('pomodoros');
    await Hive.openBox('app_init_flags');
    await pomos.put(
      'local-only',
      PomodoroModel(startTime: DateTime.now(), clientId: 'local-only'),
    );

    await SoloSyncService.instance.applySnapshot({
      'pomodoros': [
        {
          'clientId': 'remote-only',
          'startTime': DateTime.now().toIso8601String(),
          'durationMinutes': 25,
        },
      ],
    });

    expect(
      pomos.get('local-only'),
      isNotNull,
      reason: 'local session missing from the payload must survive',
    );
    expect(
      pomos.get('remote-only'),
      isNotNull,
      reason: 'session from the payload must be applied',
    );
    expect(pomos.length, 2);

    await tearDownTestHive();
  });

  test(
    'applySnapshot assigns a deterministic clientId to legacy records '
    '(re-applying the same payload twice must not create duplicates)',
    () async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PomodoroModelAdapter());
      }

      final pomos = await Hive.openBox<PomodoroModel>('pomodoros');
      await Hive.openBox('app_init_flags');

      final legacyPayload = {
        'pomodoros': [
          {
            // No clientId — simulates a pre-clientId record from the server.
            'startTime': '2026-01-01T00:00:00.000Z',
            'durationMinutes': 25,
            'project_id': 'proj-1',
          },
        ],
      };

      await SoloSyncService.instance.applySnapshot(legacyPayload);
      expect(pomos.length, 1);

      // Re-applying the exact same payload (e.g. a second sync round-trip)
      // must resolve to the same key, not add a second entry.
      await SoloSyncService.instance.applySnapshot(legacyPayload);
      expect(pomos.length, 1);

      await tearDownTestHive();
    },
  );
}

import 'dart:async';

import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_acquisition_settings.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:uuid/uuid.dart';
import 'package:solo_level_system/services/solo_sync_service.dart';
import 'package:solo_level_system/utils/journal_service.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/session_reward_service.dart';

/// A completed Pomodoro session that has been persisted, plus whatever it
/// earned (empty/null loot when [PomodoroSessionService.recordCompletedSession]
/// was called with `grantCardsAndPoints: false`).
class RecordedPomodoroSession {
  final PomodoroModel session;
  final SessionLoot? loot;

  const RecordedPomodoroSession({required this.session, this.loot});
}

/// Persists a completed Pomodoro session: writes the [PomodoroModel] record,
/// updates project/user progress stats, and (optionally) grants card/point
/// rewards.
///
/// This is the single source of truth for "what happens when a focus session
/// finishes" so both [HomeScreen] (full journal-modal + loot-dialog flow) and
/// the lightweight macOS menu-bar popover (which skips those modals) record
/// sessions identically instead of duplicating this logic.
class PomodoroSessionService {
  static final PomodoroSessionService _instance =
      PomodoroSessionService._internal();
  factory PomodoroSessionService() => _instance;
  PomodoroSessionService._internal();

  Future<RecordedPomodoroSession> recordCompletedSession({
    required int minutesSpent,
    required int dayPomodoroNumber,
    DateTime? sessionStartTime,
    ProjectModel? project,
    String? audioPath,
    String? imagePath,
    bool grantCardsAndPoints = true,
  }) async {
    final session = PomodoroModel(
      startTime: sessionStartTime ?? DateTime.now(),
      audioPath: audioPath,
      imagePath: imagePath,
      dayPomodoroNumber: dayPomodoroNumber,
      duration: minutesSpent.toString(),
      durationMinutes: minutesSpent,
      project_id: project?.id,
      project_name: project?.name,
      clientId: const Uuid().v4(),
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    await box.put(session.clientId!, session);

    // Explicit end-of-session upload hook. Redundant with the automatic
    // Hive-watcher push (any pomodoros box write already schedules one) but
    // makes the intent explicit and matches the same belt-and-suspenders
    // pattern used elsewhere (e.g. settings save) — harmless either way,
    // since schedulePush() is debounced/idempotent and offline-silent.
    SoloSyncService.instance.schedulePush();
    unawaited(SoloSyncService.instance.syncNow());

    await JournalService.addSessionCompleted(
      minutes: minutesSpent,
      projectName: project?.name,
      source: 'focus',
      accentColorHex: project?.color,
    );

    project?.addPomodoroSession(date: session.startTime);

    final userProgress = await loadOrCreateUserProgress();
    try {
      await MotivationSeedService.ensureSeeded();
    } catch (_) {
      // Non-fatal: reward seeding is best-effort, session is already saved.
    }

    SessionLoot? loot;
    userProgress.recordSession(sessionDate: session.startTime);
    if (grantCardsAndPoints) {
      final settings = liveUserSettings();
      final count =
          settings.acquisitionMode == CardAcquisitionMode.sessionCompletion
          ? settings.clampedSessionCardCount
          : 1;
      loot = SessionRewardService.grant(
        minutes: minutesSpent,
        kind: SessionKind.focus,
        progress: userProgress,
        cardCountOverride: count,
      );
      if (loot.cards.isNotEmpty) {
        unawaited(
          JournalService.addCardsEarned(
            cardTitles: loot.cards.map((c) => c.title).toList(),
            source: 'focus',
            modeWire: settings.acquisitionMode.wire,
          ),
        );
      }
    }

    return RecordedPomodoroSession(session: session, loot: loot);
  }

  /// The current [UserSettingsModel], read live from Hive (falling back to
  /// defaults). Shared by every caller that needs acquisition-mode/timing
  /// settings without holding its own cached copy.
  static UserSettingsModel liveUserSettings() {
    try {
      if (Hive.isBoxOpen('userSettings')) {
        final stored = Hive.box<UserSettingsModel>(
          'userSettings',
        ).get('settings');
        if (stored != null) return stored;
      }
    } catch (_) {}
    return UserSettingsModel();
  }

  /// Loads the singleton [UserProgressModel] wallet, creating it (with a
  /// starting balance) on first use.
  Future<UserProgressModel> loadOrCreateUserProgress() async {
    if (!Hive.isBoxOpen('userProgress')) {
      await Hive.openBox<UserProgressModel>('userProgress');
    }
    final box = Hive.box<UserProgressModel>('userProgress');
    var progress = box.get('progress');
    if (progress == null) {
      progress = UserProgressModel(availablePoints: 100);
      await box.put('progress', progress);
    }
    return progress;
  }
}

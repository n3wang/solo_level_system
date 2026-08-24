import 'package:solo_level_system/models/card_acquisition_settings.dart';
import 'package:solo_level_system/models/journal_entry_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';

const int soloSnapshotSchemaVersion = 1;

class SoloSnapshotCodec {
  static Map<String, dynamic> encode({
    required String installId,
    required UserSettingsModel settings,
    required UserProgressModel progress,
    required Iterable<ProjectModel> projects,
    required Iterable<PomodoroModel> pomodoros,
    required Iterable<WorkoutSessionModel> workouts,
    required Iterable<String> earnedCardIds,
    Iterable<JournalEntryModel> journalEntries = const [],
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'schemaVersion': soloSnapshotSchemaVersion,
      'installId': installId,
      'updatedAt': now,
      'settings': settingsToMap(settings)..['updatedAt'] = now,
      'progress': progressToMap(progress)..['updatedAt'] = now,
      'projects': projects.map(projectToMap).toList(),
      'pomodoros': pomodoros.map(pomodoroToMap).toList(),
      'workouts': workouts.map(workoutToMap).toList(),
      'earnedCardIds': earnedCardIds.toList(),
      'journalEntries': journalEntries.map(journalEntryToMap).toList(),
    };
  }

  static Map<String, dynamic> asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static List<dynamic> asList(dynamic raw) {
    if (raw is List) return raw;
    return const [];
  }

  static String? asString(dynamic raw) => raw?.toString();

  static int asInt(dynamic raw, [int fallback = 0]) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static double? asDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static bool asBool(dynamic raw, [bool fallback = false]) {
    if (raw is bool) return raw;
    if (raw is String) {
      return raw.toLowerCase() == 'true' || raw == '1';
    }
    return fallback;
  }

  static DateTime? asDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  static Map<String, dynamic> settingsToMap(UserSettingsModel s) {
    return {
      'theme': s.theme,
      'primaryColor': s.primaryColor,
      'colorPalette': s.colorPalette,
      'defaultWorkMinutes': s.defaultWorkMinutes,
      'defaultBreakMinutes': s.defaultBreakMinutes,
      'autoStartBreaks': s.autoStartBreaks,
      'autoStartWork': s.autoStartWork,
      'enableNotifications': s.enableNotifications,
      'enableSounds': s.enableSounds,
      'notificationSound': s.notificationSound,
      'audioQuality': s.audioQuality,
      'audioFormat': s.audioFormat,
      'enableNoiseReduction': s.enableNoiseReduction,
      'playAudioDuringWork': s.playAudioDuringWork,
      'playAudioDuringBreaks': s.playAudioDuringBreaks,
      'language': s.language,
      'dateFormat': s.dateFormat,
      'timeFormat': s.timeFormat,
      'enableAnalytics': s.enableAnalytics,
      'developmentDataEnabled': s.developmentDataEnabled,
      'autoOpenJournalAfterFocus': s.autoOpenJournalAfterFocus,
      'cardAcquisitionMode': s.cardAcquisitionMode,
      'sessionCompletionCardCount': s.sessionCompletionCardCount,
      'cardAcquireTiming': s.cardAcquireTiming,
      'rogueChallengeList': s.rogueChallengeList,
      'colorBackgroundBySessionMode': s.colorBackgroundBySessionMode,
      'publicProfileEnabled': s.publicProfileEnabled,
      'shareNonProjectSessions': s.shareNonProjectSessions,
      'shareJournalText': s.shareJournalText,
      'publicHandle': s.publicHandle,
    };
  }

  static UserSettingsModel settingsFromMap(
    Map<String, dynamic> map, [
    UserSettingsModel? base,
  ]) {
    final s = base ?? UserSettingsModel();
    s.theme = asString(map['theme']) ?? s.theme;
    s.primaryColor = asString(map['primaryColor']) ?? s.primaryColor;
    s.colorPalette = asString(map['colorPalette']) ?? s.colorPalette;
    s.defaultWorkMinutes = asInt(map['defaultWorkMinutes'], s.defaultWorkMinutes);
    s.defaultBreakMinutes =
        asInt(map['defaultBreakMinutes'], s.defaultBreakMinutes);
    s.autoStartBreaks = asBool(map['autoStartBreaks'], s.autoStartBreaks);
    s.autoStartWork = asBool(map['autoStartWork'], s.autoStartWork);
    s.enableNotifications =
        asBool(map['enableNotifications'], s.enableNotifications);
    s.enableSounds = asBool(map['enableSounds'], s.enableSounds);
    s.notificationSound = asString(map['notificationSound']) ?? s.notificationSound;
    s.audioQuality = asString(map['audioQuality']) ?? s.audioQuality;
    s.audioFormat = asString(map['audioFormat']) ?? s.audioFormat;
    s.enableNoiseReduction =
        asBool(map['enableNoiseReduction'], s.enableNoiseReduction);
    s.playAudioDuringWork =
        asBool(map['playAudioDuringWork'], s.playAudioDuringWork);
    s.playAudioDuringBreaks =
        asBool(map['playAudioDuringBreaks'], s.playAudioDuringBreaks);
    s.language = asString(map['language']) ?? s.language;
    s.dateFormat = asString(map['dateFormat']) ?? s.dateFormat;
    s.timeFormat = asString(map['timeFormat']) ?? s.timeFormat;
    s.enableAnalytics = asBool(map['enableAnalytics'], s.enableAnalytics);
    s.developmentDataEnabled =
        asBool(map['developmentDataEnabled'], s.developmentDataEnabled);
    s.autoOpenJournalAfterFocus =
        asBool(map['autoOpenJournalAfterFocus'], s.autoOpenJournalAfterFocus);
    s.cardAcquisitionMode =
        asString(map['cardAcquisitionMode']) ?? s.cardAcquisitionMode;
    s.sessionCompletionCardCount = asInt(
      map['sessionCompletionCardCount'],
      s.sessionCompletionCardCount,
    );
    s.cardAcquireTiming =
        asString(map['cardAcquireTiming']) ?? s.cardAcquireTiming;
    final rogue = map['rogueChallengeList'];
    if (rogue is List) {
      s.rogueChallengeList = rogue.map((e) => e.toString()).toList();
    }
    s.colorBackgroundBySessionMode = asBool(
      map['colorBackgroundBySessionMode'],
      s.colorBackgroundBySessionMode,
    );
    s.publicProfileEnabled =
        asBool(map['publicProfileEnabled'], s.publicProfileEnabled);
    s.shareNonProjectSessions =
        asBool(map['shareNonProjectSessions'], s.shareNonProjectSessions);
    s.shareJournalText = asBool(map['shareJournalText'], s.shareJournalText);
    s.publicHandle = asString(map['publicHandle']) ?? s.publicHandle;
    s.rogueChallengeList = RogueChallengeDefaults.normalize(
      s.rogueChallengeList,
      includeDev: false,
    );
    return s;
  }

  static Map<String, dynamic> progressToMap(UserProgressModel p) {
    return {
      'availablePoints': p.availablePoints,
      'totalPointsEarned': p.totalPointsEarned,
      'totalPointsSpent': p.totalPointsSpent,
      'totalPomodoroSessions': p.totalPomodoroSessions,
      'lastSessionDate': p.lastSessionDate?.toIso8601String(),
      'currentStreak': p.currentStreak,
      'longestStreak': p.longestStreak,
      'dailySessionCount': p.dailySessionCount,
      'weeklyStats': p.weeklyStats,
    };
  }

  static UserProgressModel progressFromMap(
    Map<String, dynamic> map, [
    UserProgressModel? base,
  ]) {
    final p = base ?? UserProgressModel();
    p.availablePoints = asInt(map['availablePoints'], p.availablePoints);
    p.totalPointsEarned = asInt(map['totalPointsEarned'], p.totalPointsEarned);
    p.totalPointsSpent = asInt(map['totalPointsSpent'], p.totalPointsSpent);
    p.totalPomodoroSessions =
        asInt(map['totalPomodoroSessions'], p.totalPomodoroSessions);
    p.lastSessionDate = asDate(map['lastSessionDate']) ?? p.lastSessionDate;
    p.currentStreak = asInt(map['currentStreak'], p.currentStreak);
    p.longestStreak = asInt(map['longestStreak'], p.longestStreak);
    p.dailySessionCount = _stringIntMap(map['dailySessionCount'], p.dailySessionCount);
    p.weeklyStats = _stringIntMap(map['weeklyStats'], p.weeklyStats);
    return p;
  }

  static Map<String, dynamic> projectToMap(ProjectModel p) {
    return {
      'clientId': p.id,
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'color': p.color,
      'iconName': p.iconName,
      'isActive': p.isActive,
      'createdAt': p.createdAt.toIso8601String(),
      'archivedAt': p.archivedAt?.toIso8601String(),
      'habitIds': p.habitIds,
      'weeklyPomodoroTargets': p.weeklyPomodoroTargets.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'activeDays': p.activeDays,
      'totalCompletedPomodoros': p.totalCompletedPomodoros,
      'lastWorkedOn': p.lastWorkedOn?.toIso8601String(),
      'dailyStats': p.dailyStats,
      'priority': p.priority,
      'notes': p.notes,
      'tags': p.tags,
      'targetType': p.targetType,
      'dailySessionTarget': p.dailySessionTarget,
      'weeklySessionTarget': p.weeklySessionTarget,
      'preferredWorkHour': p.preferredWorkHour,
      'workDurationMinutes': p.workDurationMinutes,
      'breakDurationMinutes': p.breakDurationMinutes,
      'shareProgress': p.shareProgress,
      'updatedAt': (p.lastWorkedOn ?? p.createdAt).toUtc().toIso8601String(),
    };
  }

  static ProjectModel projectFromMap(Map<String, dynamic> map) {
    final id = asString(map['clientId']) ?? asString(map['id']) ?? '';
    final weekly = <int, int>{};
    final weeklyRaw = map['weeklyPomodoroTargets'];
    if (weeklyRaw is Map) {
      weeklyRaw.forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null) weekly[key] = asInt(v);
      });
    }
    return ProjectModel(
      id: id,
      name: asString(map['name']) ?? 'Project',
      description: asString(map['description']),
      color: asString(map['color']) ?? '#4CAF50',
      iconName: asString(map['iconName']),
      isActive: asBool(map['isActive'], true),
      createdAt: asDate(map['createdAt']) ?? DateTime.now(),
      archivedAt: asDate(map['archivedAt']),
      habitIds: _stringList(map['habitIds']),
      weeklyPomodoroTargets: weekly,
      activeDays: _intList(map['activeDays'], const [1, 2, 3, 4, 5]),
      totalCompletedPomodoros: asInt(map['totalCompletedPomodoros']),
      lastWorkedOn: asDate(map['lastWorkedOn']),
      dailyStats: _stringIntMap(map['dailyStats'], const {}),
      priority: asInt(map['priority'], 1),
      notes: asString(map['notes']),
      tags: _stringList(map['tags']),
      targetType: asString(map['targetType']) ?? 'daily',
      dailySessionTarget: asInt(map['dailySessionTarget'], 2),
      weeklySessionTarget: asInt(map['weeklySessionTarget'], 10),
      preferredWorkHour: map['preferredWorkHour'] == null
          ? null
          : asInt(map['preferredWorkHour']),
      workDurationMinutes: asInt(map['workDurationMinutes'], 25),
      breakDurationMinutes: asInt(map['breakDurationMinutes'], 5),
      shareProgress: asBool(map['shareProgress'], false),
    );
  }

  static Map<String, dynamic> pomodoroToMap(PomodoroModel p) {
    return {
      'clientId': p.clientId,
      'startTime': p.startTime.toIso8601String(),
      'audioPath': p.audioPath,
      'imagePath': p.imagePath,
      'dayPomodoroNumber': p.dayPomodoroNumber,
      'duration': p.duration,
      'project_id': p.project_id,
      'project_name': p.project_name,
      'durationMinutes': p.durationMinutes ?? p.minutesSpent,
      'updatedAt': p.startTime.toUtc().toIso8601String(),
    };
  }

  static PomodoroModel pomodoroFromMap(Map<String, dynamic> map) {
    return PomodoroModel(
      startTime: asDate(map['startTime']) ?? DateTime.now(),
      audioPath: asString(map['audioPath']),
      imagePath: asString(map['imagePath']),
      dayPomodoroNumber:
          map['dayPomodoroNumber'] == null ? null : asInt(map['dayPomodoroNumber']),
      duration: asString(map['duration']),
      project_id: asString(map['project_id']),
      project_name: asString(map['project_name']),
      durationMinutes:
          map['durationMinutes'] == null ? null : asInt(map['durationMinutes']),
      clientId: asString(map['clientId']),
    );
  }

  static Map<String, dynamic> workoutToMap(WorkoutSessionModel w) {
    return {
      'clientId': w.id,
      'id': w.id,
      'routineId': w.routineId,
      'routineName': w.routineName,
      'startTime': w.startTime.toIso8601String(),
      'endTime': w.endTime?.toIso8601String(),
      'durationMinutes': w.durationMinutes,
      'completedExerciseIds': w.completedExerciseIds,
      'exerciseCompletedSets': w.exerciseCompletedSets,
      'isCompleted': w.isCompleted,
      'status': w.status,
      'notes': w.notes,
      'totalWeightLifted': w.totalWeightLifted,
      'totalSetsCompleted': w.totalSetsCompleted,
      'totalRepsCompleted': w.totalRepsCompleted,
      'personalRecordsSet': w.personalRecordsSet,
      'averageHeartRate': w.averageHeartRate,
      'tags': w.tags,
      'location': w.location,
      'additionalData': w.additionalData,
      'updatedAt': (w.endTime ?? w.startTime).toUtc().toIso8601String(),
    };
  }

  static WorkoutSessionModel workoutFromMap(Map<String, dynamic> map) {
    final id = asString(map['clientId']) ?? asString(map['id']) ?? '';
    return WorkoutSessionModel(
      id: id,
      routineId: asString(map['routineId']) ?? '',
      routineName: asString(map['routineName']) ?? '',
      startTime: asDate(map['startTime']) ?? DateTime.now(),
      endTime: asDate(map['endTime']),
      durationMinutes: asInt(map['durationMinutes']),
      completedExerciseIds: _stringList(map['completedExerciseIds']),
      exerciseCompletedSets: _stringIntMap(map['exerciseCompletedSets'], const {}),
      isCompleted: asBool(map['isCompleted']),
      status: asString(map['status']) ?? 'completed',
      notes: asString(map['notes']),
      totalWeightLifted: asDouble(map['totalWeightLifted']),
      totalSetsCompleted: asInt(map['totalSetsCompleted']),
      totalRepsCompleted: asInt(map['totalRepsCompleted']),
      personalRecordsSet: _stringList(map['personalRecordsSet']),
      averageHeartRate: asDouble(map['averageHeartRate']),
      tags: _stringList(map['tags']),
      location: asString(map['location']),
      additionalData: asStringKeyedMap(map['additionalData']),
    );
  }

  static Map<String, dynamic> journalEntryToMap(JournalEntryModel e) {
    return {
      'clientId': e.id,
      'id': e.id,
      'type': e.type,
      'createdAt': e.createdAt.toIso8601String(),
      'text': e.text,
      'mediaPath': e.mediaPath,
      'durationMs': e.durationMs,
      'projectName': e.projectName,
      'sessionMinutes': e.sessionMinutes,
      'source': e.source,
      'metadata': e.metadata,
      'updatedAt': e.createdAt.toUtc().toIso8601String(),
    };
  }

  static JournalEntryModel journalEntryFromMap(Map<String, dynamic> map) {
    final id = asString(map['clientId']) ?? asString(map['id']) ?? '';
    return JournalEntryModel(
      id: id,
      type: asString(map['type']) ?? 'text',
      createdAt: asDate(map['createdAt']) ?? DateTime.now(),
      text: asString(map['text']),
      mediaPath: asString(map['mediaPath']),
      durationMs: map['durationMs'] == null ? null : asInt(map['durationMs']),
      projectName: asString(map['projectName']),
      sessionMinutes:
          map['sessionMinutes'] == null ? null : asInt(map['sessionMinutes']),
      source: asString(map['source']) ?? 'free',
      metadata: asStringKeyedMap(map['metadata']),
    );
  }

  static Map<String, int> _stringIntMap(dynamic raw, Map<String, int> fallback) {
    if (raw is! Map) return Map<String, int>.from(fallback);
    final out = <String, int>{};
    raw.forEach((k, v) => out[k.toString()] = asInt(v));
    return out;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  static List<int> _intList(dynamic raw, List<int> fallback) {
    if (raw is! List) return List<int>.from(fallback);
    return raw.map((e) => asInt(e)).toList();
  }
}

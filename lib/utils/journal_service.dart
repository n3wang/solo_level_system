import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/journal_entry_model.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/utils/workout_motivation_service.dart';

class JournalService {
  JournalService._();

  static const String boxName = 'journalEntries';
  static const String _flagsBoxName = 'app_init_flags';
  static const String _campaignModeKey = 'campaign_mode_enabled';
  static const String parentSessionIdKey = 'parentSessionId';
  static const String sessionOrdinalKey = 'sessionOrdinal';
  static const String workoutSessionIdKey = 'workoutSessionId';
  static const String inProgressKey = 'inProgress';
  static const String accentColorKey = 'accentColor';

  static Future<Box<JournalEntryModel>> ensureBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return Hive.openBox<JournalEntryModel>(boxName);
    }
    return Hive.box<JournalEntryModel>(boxName);
  }

  static bool get campaignModeEnabled {
    if (!Hive.isBoxOpen(_flagsBoxName)) return false;
    return Hive.box(_flagsBoxName).get(_campaignModeKey, defaultValue: false)
        as bool;
  }

  static Future<void> setCampaignModeEnabled(bool enabled) async {
    if (!Hive.isBoxOpen(_flagsBoxName)) {
      await Hive.openBox(_flagsBoxName);
    }
    await Hive.box(_flagsBoxName).put(_campaignModeKey, enabled);
  }

  static String _newId() =>
      'journal_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  static String? parentSessionIdOf(JournalEntryModel entry) {
    final raw = entry.metadata[parentSessionIdKey];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  static int sessionOrdinalOf(JournalEntryModel entry) {
    final raw = entry.metadata[sessionOrdinalKey];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 1;
  }

  /// Display title: `[f2-25] ERPNext project` / `[w2] Lower Body Gym`
  static String formatSessionTitle(JournalEntryModel session) {
    final ordinal = sessionOrdinalOf(session);
    final name = (session.projectName ?? '').trim().isNotEmpty
        ? session.projectName!.trim()
        : (session.source == 'workout' ? 'Workout' : 'Focus session');

    if (session.source == 'workout') {
      return '[w$ordinal] $name';
    }

    final inProgress = session.metadata[inProgressKey] == true;
    final minsPart = inProgress ? '…' : '${session.sessionMinutes ?? 0}';
    return '[f$ordinal-$minsPart] $name';
  }

  static String? workoutSessionIdOf(JournalEntryModel entry) {
    final raw = entry.metadata[workoutSessionIdKey];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  static String? accentColorHexOf(JournalEntryModel entry) {
    final raw = entry.metadata[accentColorKey];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  /// Grouping accent: project color (focus), set color (workout), else null
  /// (caller should fall back to theme primary for misc/other).
  static Color? resolveGroupingColor(JournalEntryModel session) {
    final stored = AppColorPalette.hexToColor(accentColorHexOf(session));
    if (stored != null) return stored;

    if (session.source == 'focus') {
      return _lookupProjectColor(session.projectName);
    }
    if (session.source == 'workout') {
      return _lookupWorkoutSetColor(session);
    }
    return null;
  }

  static Color? _lookupProjectColor(String? projectName) {
    final name = projectName?.trim();
    if (name == null || name.isEmpty) return null;
    if (!Hive.isBoxOpen('projects')) return null;
    for (final project in Hive.box<ProjectModel>('projects').values) {
      if (project.name.trim() == name) {
        return AppColorPalette.hexToColor(project.color);
      }
    }
    return null;
  }

  static Color? _lookupWorkoutSetColor(JournalEntryModel session) {
    String? setCategoryId;
    final workoutId = workoutSessionIdOf(session);
    if (workoutId != null && Hive.isBoxOpen('workoutSessions')) {
      final workout = Hive.box<WorkoutSessionModel>('workoutSessions').get(
        workoutId,
      );
      if (workout != null) {
        setCategoryId =
            workout.additionalData['setCategoryId'] as String? ??
            workout.routineId;
      }
    }

    if (!Hive.isBoxOpen('workoutSetCategories')) return null;
    final sets = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');

    if (setCategoryId != null) {
      for (final set in sets.values) {
        if (set.id == setCategoryId) {
          return AppColorPalette.colorForSetPosition(set.position);
        }
      }
    }

    final name = session.projectName?.trim();
    if (name != null && name.isNotEmpty) {
      for (final set in sets.values) {
        if (set.name.trim() == name) {
          return AppColorPalette.colorForSetPosition(set.position);
        }
      }
    }
    return null;
  }

  static JournalEntryModel? findByWorkoutSessionId(String workoutSessionId) {
    if (!Hive.isBoxOpen(boxName)) return null;
    for (final entry in Hive.box<JournalEntryModel>(boxName).values) {
      if (!entry.isSession) continue;
      if (workoutSessionIdOf(entry) == workoutSessionId) return entry;
    }
    return null;
  }

  /// Creates (or returns) an in-progress workout journal session so notes can
  /// attach while the set/session is still running.
  static Future<JournalEntryModel> ensureActiveWorkoutSessionNote({
    required String workoutSessionId,
    required String routineName,
    String? accentColorHex,
  }) async {
    final existing = findByWorkoutSessionId(workoutSessionId);
    if (existing != null) {
      if (accentColorHex != null &&
          accentColorHex.isNotEmpty &&
          accentColorHexOf(existing) == null) {
        existing.metadata = {
          ...existing.metadata,
          accentColorKey: accentColorHex,
        };
        await existing.save();
      }
      return existing;
    }

    final day = DateTime.now();
    final ordinal = entriesForDay(day)
            .where((e) => e.isSession && e.source == 'workout')
            .length +
        1;
    final trimmedName = routineName.trim().isEmpty ? 'Workout' : routineName.trim();
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'session',
      createdAt: DateTime.now(),
      projectName: trimmedName,
      sessionMinutes: 0,
      source: 'workout',
      metadata: {
        sessionOrdinalKey: ordinal,
        workoutSessionIdKey: workoutSessionId,
        inProgressKey: true,
        'fullyCompleted': false,
        if (accentColorHex != null && accentColorHex.isNotEmpty)
          accentColorKey: accentColorHex,
      },
    );
    entry.text = formatSessionTitle(entry);
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  /// Finalize an in-progress workout journal session when the workout ends.
  /// Creates one if notes were never opened mid-session.
  static Future<JournalEntryModel> finalizeWorkoutSessionNote({
    required String workoutSessionId,
    required int minutes,
    required String routineName,
    bool fullyCompleted = true,
    String? accentColorHex,
  }) async {
    final existing = findByWorkoutSessionId(workoutSessionId);
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final trimmedName =
        routineName.trim().isEmpty ? 'Workout' : routineName.trim();

    if (existing != null) {
      existing
        ..sessionMinutes = safeMinutes
        ..projectName = trimmedName
        ..metadata = {
          ...existing.metadata,
          inProgressKey: false,
          'fullyCompleted': fullyCompleted,
          workoutSessionIdKey: workoutSessionId,
          if (accentColorHex != null && accentColorHex.isNotEmpty)
            accentColorKey: accentColorHex,
        };
      existing.text = formatSessionTitle(existing);
      await existing.save();
      return existing;
    }

    return addSessionCompleted(
      minutes: safeMinutes,
      projectName: trimmedName,
      source: 'workout',
      fullyCompleted: fullyCompleted,
      workoutSessionId: workoutSessionId,
      accentColorHex: accentColorHex,
    );
  }

  static Map<String, dynamic> _metaWithParent(String? parentSessionId) {
    if (parentSessionId == null || parentSessionId.isEmpty) return const {};
    return {parentSessionIdKey: parentSessionId};
  }

  static Future<JournalEntryModel> addText({
    required String text,
    String source = 'free',
    String? parentSessionId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Journal text cannot be empty');
    }
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'text',
      createdAt: DateTime.now(),
      text: trimmed,
      source: source,
      metadata: _metaWithParent(parentSessionId),
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  /// Saves a citation note: italic quote body + `--- author` attribution.
  static Future<JournalEntryModel> addCitation({
    required String quote,
    required String author,
    String source = 'free',
    String? parentSessionId,
  }) async {
    final trimmedQuote = quote.trim();
    if (trimmedQuote.isEmpty) {
      throw ArgumentError('Citation quote cannot be empty');
    }
    final trimmedAuthor = author.trim().isEmpty ? 'Unknown' : author.trim();
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'text',
      createdAt: DateTime.now(),
      text: trimmedQuote,
      source: source,
      metadata: {
        ..._metaWithParent(parentSessionId),
        'citation': true,
        'author': trimmedAuthor,
      },
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  static bool isCitation(JournalEntryModel entry) =>
      entry.isText && entry.metadata['citation'] == true;

  static Future<JournalEntryModel> addAudio({
    required String mediaPath,
    int? durationMs,
    String source = 'free',
    String? parentSessionId,
  }) async {
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'audio',
      createdAt: DateTime.now(),
      mediaPath: mediaPath,
      durationMs: durationMs,
      source: source,
      metadata: _metaWithParent(parentSessionId),
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  static Future<JournalEntryModel> addImage({
    required String mediaPath,
    String source = 'free',
    String? parentSessionId,
  }) async {
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'image',
      createdAt: DateTime.now(),
      mediaPath: mediaPath,
      source: source,
      metadata: _metaWithParent(parentSessionId),
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  static Future<JournalEntryModel> addSessionCompleted({
    required int minutes,
    String? projectName,
    String source = 'focus',
    bool fullyCompleted = true,
    String? workoutSessionId,
    String? accentColorHex,
  }) async {
    final trimmedName = projectName?.trim();
    final day = DateTime.now();
    final ordinal =
        entriesForDay(day).where((e) => e.isSession && e.source == source).length +
        1;
    final metadata = <String, dynamic>{
      'fullyCompleted': fullyCompleted,
      sessionOrdinalKey: ordinal,
      inProgressKey: false,
      if (workoutSessionId != null && workoutSessionId.isNotEmpty)
        workoutSessionIdKey: workoutSessionId,
      if (accentColorHex != null && accentColorHex.isNotEmpty)
        accentColorKey: accentColorHex,
    };
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'session',
      createdAt: DateTime.now(),
      projectName: trimmedName,
      sessionMinutes: minutes,
      source: source,
      metadata: metadata,
    );
    entry.text = formatSessionTitle(entry);
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  static Future<JournalEntryModel?> ensureDailyQuote({
    required DateTime day,
  }) async {
    final existing = entriesForDay(day).where((e) => e.isQuote).toList();
    if (existing.isNotEmpty) return existing.first;

    final vm = WorkoutMotivationService.randomAcquiredQuote() ??
        WorkoutMotivationService.fallbackQuote;
    final entry = JournalEntryModel(
      id: _newId(),
      type: 'quote',
      createdAt: DateTime(day.year, day.month, day.day, 0, 0, 1),
      text: vm.quote.trim(),
      source: 'journal',
      metadata: _quoteMetadata(vm),
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  /// Replaces today's journal quote with another random acquired quote.
  static Future<JournalEntryModel?> randomizeDailyQuote({
    required DateTime day,
  }) async {
    final existing = entriesForDay(day).where((e) => e.isQuote).toList();
    final current = existing.isEmpty ? null : existing.first;
    final next = WorkoutMotivationService.randomAcquiredQuote(
          excludeQuote: current?.text,
          excludeItemId: current?.metadata['itemId'] as String?,
        ) ??
        WorkoutMotivationService.fallbackQuote;

    if (current != null) {
      current
        ..text = next.quote.trim()
        ..source = 'journal'
        ..metadata = _quoteMetadata(next);
      await current.save();
      return current;
    }

    final entry = JournalEntryModel(
      id: _newId(),
      type: 'quote',
      createdAt: DateTime(day.year, day.month, day.day, 0, 0, 1),
      text: next.quote.trim(),
      source: 'journal',
      metadata: _quoteMetadata(next),
    );
    final box = await ensureBox();
    await box.add(entry);
    return entry;
  }

  static Map<String, dynamic> _quoteMetadata(WorkoutQuoteVm vm) {
    return {
      'itemId': vm.itemId,
      'author': vm.author,
      'aboutAuthor': vm.aboutAuthor,
      if (vm.imageIndex != null) 'imageIndex': vm.imageIndex,
    };
  }

  @Deprecated('Use ensureDailyQuote')
  static Future<JournalEntryModel?> addCampaignQuoteIfNeeded({
    required DateTime day,
  }) =>
      ensureDailyQuote(day: day);

  static List<JournalEntryModel> entriesForDay(DateTime day) {
    if (!Hive.isBoxOpen(boxName)) return const [];
    final box = Hive.box<JournalEntryModel>(boxName);
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final entries = box.values
        .where((e) => !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Lightweight scan: only calendar days that have at least one entry.
  /// Does not materialize full day feeds — call only when opening the picker.
  static List<DateTime> daysWithEntries({bool includeToday = true}) {
    if (!Hive.isBoxOpen(boxName)) {
      return includeToday ? [dayOnly(DateTime.now())] : const [];
    }
    final keys = <String>{};
    for (final entry in Hive.box<JournalEntryModel>(boxName).values) {
      // Quotes alone still mark the day as available.
      keys.add(dayKey(entry.createdAt));
    }
    if (includeToday) keys.add(dayKey(DateTime.now()));

    final days = keys.map((key) {
      final parts = key.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList()
      ..sort((a, b) => a.compareTo(b)); // oldest → newest for reverse lists
    return days;
  }

  /// Groups [days] (oldest→newest) into month buckets, each day's list ascending.
  static List<({int year, int month, List<DateTime> days})> groupDaysByMonth(
    List<DateTime> days,
  ) {
    final groups = <({int year, int month, List<DateTime> days})>[];
    for (final day in days) {
      if (groups.isEmpty ||
          groups.last.year != day.year ||
          groups.last.month != day.month) {
        groups.add((year: day.year, month: day.month, days: [day]));
      } else {
        groups.last.days.add(day);
      }
    }
    return groups;
  }

  /// Most recent completed session for [day], optionally filtered by [source].
  static JournalEntryModel? latestSessionForDay(
    DateTime day, {
    String? source,
  }) {
    final sessions = entriesForDay(day).where((e) {
      if (!e.isSession) return false;
      if (source == null) return true;
      return e.source == source;
    }).toList();
    if (sessions.isEmpty) return null;
    return sessions.last;
  }

  static Future<void> deleteEntry(JournalEntryModel entry) async {
    await entry.delete();
  }
}

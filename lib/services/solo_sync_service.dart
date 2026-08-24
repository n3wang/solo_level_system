import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/journal_entry_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/install_id_service.dart';
import '../sync/solo_snapshot.dart';

class SoloSyncService {
  SoloSyncService({ApiClient? client}) : _client = client ?? ApiClient();

  static final SoloSyncService instance = SoloSyncService();

  final ApiClient _client;
  static const _outboxBox = 'soloSync_outbox';
  static const _pendingCardsKey = 'pendingEarnedCardIds';
  bool _applying = false;
  bool _syncing = false;
  Timer? _debounce;
  bool _watchersAttached = false;

  /// Bumped after a snapshot is applied so UI can refresh today's marks.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<void> attachWatchers() async {
    if (_watchersAttached) return;
    _watchersAttached = true;
    void listen(Box box) {
      box.watch().listen((_) {
        if (_applying) return;
        schedulePush();
      });
    }

    try {
      if (Hive.isBoxOpen('pomodoros')) {
        listen(Hive.box<PomodoroModel>('pomodoros'));
      }
      if (Hive.isBoxOpen('userSettings')) {
        listen(Hive.box<UserSettingsModel>('userSettings'));
      }
      if (Hive.isBoxOpen('userProgress')) {
        listen(Hive.box<UserProgressModel>('userProgress'));
      }
      if (Hive.isBoxOpen('projects')) {
        listen(Hive.box<ProjectModel>('projects'));
      }
      if (Hive.isBoxOpen('workoutSessions')) {
        listen(Hive.box<WorkoutSessionModel>('workoutSessions'));
      }
      if (Hive.isBoxOpen('motivationItems')) {
        listen(Hive.box<CardModel>('motivationItems'));
      }
      if (Hive.isBoxOpen('journalEntries')) {
        listen(Hive.box<JournalEntryModel>('journalEntries'));
      }
    } catch (_) {
      _watchersAttached = false;
    }
  }

  void schedulePush() {
    if (!AccountSession.instance.loggedIn.value) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(pushSnapshot());
    });
  }

  /// Returns true if cloud snapshot was applied/uploaded. False means local
  /// data stays and sync is queued until the backend is reachable.
  Future<bool> onLoggedIn() async {
    await attachWatchers();
    try {
      await ensurePomodoroClientIds();
      final local = await buildSnapshot();
      final get = await _client.get('/api/solo/snapshot');
      if (get.statusCode < 200 || get.statusCode >= 300) {
        await _saveOutbox(local);
        return false;
      }
      final body = decodeJsonMap(get.body);
      final exists = SoloSnapshotCodec.asBool(body['exists']);
      if (!exists) {
        await _put(local);
      } else {
        final merge = await _client.post('/api/solo/merge', local);
        if (merge.statusCode < 200 || merge.statusCode >= 300) {
          await _saveOutbox(local);
          return false;
        }
        final merged = decodeJsonMap(merge.body);
        await applySnapshot(
          SoloSnapshotCodec.asStringKeyedMap(merged['payload']),
        );
      }
      await _clearOutbox();
      return true;
    } catch (_) {
      try {
        await _saveOutbox(await buildSnapshot());
      } catch (_) {}
      return false;
    }
  }

  /// Best-effort two-way sync: sends the local snapshot to `/api/solo/merge`
  /// (so this device's not-yet-pushed sessions reach the server too) and
  /// applies whatever merged result comes back (so other devices' sessions
  /// show up here). Meant to be called fire-and-forget at natural
  /// checkpoints (e.g. session start) — silent no-op when logged out,
  /// offline, or a call is already in flight; never throws.
  Future<void> syncNow() async {
    if (!AccountSession.instance.loggedIn.value || _syncing) return;
    _syncing = true;
    try {
      await ensurePomodoroClientIds();
      final local = await buildSnapshot();
      final merge = await _client.post('/api/solo/merge', local);
      if (merge.statusCode < 200 || merge.statusCode >= 300) {
        await _saveOutbox(local);
        return;
      }
      final merged = decodeJsonMap(merge.body);
      final payload = merged['payload'];
      if (payload == null) {
        await _saveOutbox(local);
        return;
      }
      await applySnapshot(SoloSnapshotCodec.asStringKeyedMap(payload));
      await _clearOutbox();
    } catch (_) {
      try {
        await _saveOutbox(await buildSnapshot());
      } catch (_) {}
    } finally {
      _syncing = false;
    }
  }

  Future<void> pushSnapshot() async {
    await syncNow();
  }

  Future<void> retryOutbox() async {
    await syncNow();
  }

  Future<void> logoutAndWipeStats() async {
    _debounce?.cancel();
    _applying = true;
    try {
      if (Hive.isBoxOpen('pomodoros')) {
        await Hive.box<PomodoroModel>('pomodoros').clear();
      }
      if (Hive.isBoxOpen('workoutSessions')) {
        await Hive.box<WorkoutSessionModel>('workoutSessions').clear();
      }
      if (Hive.isBoxOpen('userProgress')) {
        await Hive.box<UserProgressModel>(
          'userProgress',
        ).put('progress', UserProgressModel());
      }
      if (Hive.isBoxOpen('projects')) {
        final box = Hive.box<ProjectModel>('projects');
        for (final project in box.values) {
          project.totalCompletedPomodoros = 0;
          project.dailyStats = {};
          project.lastWorkedOn = null;
          await project.save();
        }
      }
      if (Hive.isBoxOpen('motivationItems')) {
        final box = Hive.box<CardModel>('motivationItems');
        for (final card in box.values) {
          if (card.isStarter) continue;
          card.isAcquired = false;
          card.acquiredAt = null;
          card.acquisitionCount = 0;
          card.acquisitionHistory = [];
          await card.save();
        }
      }
      final flags = Hive.isBoxOpen('app_init_flags')
          ? Hive.box('app_init_flags')
          : await Hive.openBox('app_init_flags');
      await flags.delete(_pendingCardsKey);
    } finally {
      _applying = false;
    }
  }

  Future<Map<String, dynamic>> buildSnapshot() async {
    final installId = await InstallIdService.getOrCreate();
    final settings =
        Hive.box<UserSettingsModel>('userSettings').get('settings') ??
        UserSettingsModel();
    final progress =
        Hive.box<UserProgressModel>('userProgress').get('progress') ??
        UserProgressModel();
    final projects = Hive.box<ProjectModel>('projects').values;
    final pomodoros = Hive.box<PomodoroModel>('pomodoros').values;
    final workouts = Hive.isBoxOpen('workoutSessions')
        ? Hive.box<WorkoutSessionModel>('workoutSessions').values
        : <WorkoutSessionModel>[];
    final cards = Hive.isBoxOpen('motivationItems')
        ? Hive.box<CardModel>(
            'motivationItems',
          ).values.where((c) => c.isAcquired).map((c) => c.id)
        : <String>[];
    final flags = Hive.box('app_init_flags');
    final pending = flags.get(_pendingCardsKey);
    final pendingIds = pending is List
        ? pending.map((e) => e.toString())
        : const <String>[];
    final journalEntries = Hive.isBoxOpen('journalEntries')
        ? Hive.box<JournalEntryModel>('journalEntries').values
        : <JournalEntryModel>[];
    return SoloSnapshotCodec.encode(
      installId: installId,
      settings: settings,
      progress: progress,
      projects: projects,
      pomodoros: pomodoros,
      workouts: workouts,
      earnedCardIds: {...cards, ...pendingIds},
      journalEntries: journalEntries,
    );
  }

  Future<void> applySnapshot(Map<String, dynamic> payload) async {
    _applying = true;
    try {
      if (payload['settings'] != null) {
        final box = Hive.box<UserSettingsModel>('userSettings');
        final current = box.get('settings') ?? UserSettingsModel();
        final next = SoloSnapshotCodec.settingsFromMap(
          SoloSnapshotCodec.asStringKeyedMap(payload['settings']),
          current,
        );
        await box.put('settings', next);
      }
      if (payload['progress'] != null) {
        final box = Hive.box<UserProgressModel>('userProgress');
        final current = box.get('progress') ?? UserProgressModel();
        final next = SoloSnapshotCodec.progressFromMap(
          SoloSnapshotCodec.asStringKeyedMap(payload['progress']),
          current,
        );
        await box.put('progress', next);
      }
      for (final raw in SoloSnapshotCodec.asList(payload['projects'])) {
        final project = SoloSnapshotCodec.projectFromMap(
          SoloSnapshotCodec.asStringKeyedMap(raw),
        );
        if (project.id.isEmpty) continue;
        await Hive.box<ProjectModel>('projects').put(project.id, project);
      }
      if (payload.containsKey('pomodoros')) {
        // Upsert by clientId — never clear first. Pomodoro history is an
        // append-only log shared across devices: a device that hasn't
        // pushed its latest session yet must not have that local session
        // wiped out just because it wasn't in the payload we're applying.
        final box = Hive.box<PomodoroModel>('pomodoros');
        for (final raw in SoloSnapshotCodec.asList(payload['pomodoros'])) {
          final session = SoloSnapshotCodec.pomodoroFromMap(
            SoloSnapshotCodec.asStringKeyedMap(raw),
          );
          // Deterministic, not random: a legacy record without a clientId
          // must resolve to the same key every time this is applied, or
          // re-syncing the same payload would pile up duplicate entries now
          // that this loop no longer clears the box first.
          session.clientId ??=
              'pomo_${session.startTime.millisecondsSinceEpoch}_${session.project_id ?? 'none'}_${session.minutesSpent}';
          await box.put(session.clientId!, session);
        }
      }
      if (payload.containsKey('workouts') &&
          Hive.isBoxOpen('workoutSessions')) {
        final box = Hive.box<WorkoutSessionModel>('workoutSessions');
        for (final raw in SoloSnapshotCodec.asList(payload['workouts'])) {
          final session = SoloSnapshotCodec.workoutFromMap(
            SoloSnapshotCodec.asStringKeyedMap(raw),
          );
          if (session.id.isEmpty) continue;
          await box.put(session.id, session);
        }
      }
      if (payload.containsKey('journalEntries') &&
          Hive.isBoxOpen('journalEntries')) {
        // Upsert by `id` — never clear first, same append-only contract as
        // pomodoros above. Journal entries are added locally via `box.add`
        // (auto-increment keys), so — unlike pomodoros/workouts — we can't
        // just `box.put(id, entry)`; instead find the existing HiveObject by
        // its `id` field and update it in place, or add a new one.
        final box = Hive.box<JournalEntryModel>('journalEntries');
        final byId = {
          for (final e in box.values)
            if (e.id.isNotEmpty) e.id: e,
        };
        for (final raw in SoloSnapshotCodec.asList(payload['journalEntries'])) {
          final incoming = SoloSnapshotCodec.journalEntryFromMap(
            SoloSnapshotCodec.asStringKeyedMap(raw),
          );
          if (incoming.id.isEmpty) continue;
          final existing = byId[incoming.id];
          if (existing != null) {
            existing
              ..type = incoming.type
              ..createdAt = incoming.createdAt
              ..text = incoming.text
              ..mediaPath = incoming.mediaPath
              ..durationMs = incoming.durationMs
              ..projectName = incoming.projectName
              ..sessionMinutes = incoming.sessionMinutes
              ..source = incoming.source
              ..metadata = incoming.metadata;
            await existing.save();
          } else {
            await box.add(incoming);
          }
        }
      }
      await _applyEarnedCards(
        SoloSnapshotCodec.asList(
          payload['earnedCardIds'],
        ).map((e) => e.toString()).toList(),
      );
    } finally {
      _applying = false;
      revision.value++;
    }
  }

  Future<void> ensurePomodoroClientIds() async {
    if (!Hive.isBoxOpen('pomodoros')) return;
    final box = Hive.box<PomodoroModel>('pomodoros');
    final seen = <String>{};
    for (final key in box.keys.toList()) {
      final session = box.get(key);
      if (session == null) continue;
      session.clientId ??=
          'pomo_${session.startTime.millisecondsSinceEpoch}_${session.project_id ?? 'none'}_${session.minutesSpent}';
      final id = session.clientId!;
      if (seen.contains(id) && key != id) {
        await box.delete(key);
        continue;
      }
      seen.add(id);
      if (key != id) {
        await box.put(id, session);
        await box.delete(key);
      } else {
        await session.save();
      }
    }
  }

  Future<void> _applyEarnedCards(List<String> ids) async {
    final flags = Hive.box('app_init_flags');
    final unknown = <String>[];
    if (Hive.isBoxOpen('motivationItems')) {
      final box = Hive.box<CardModel>('motivationItems');
      final byId = {for (final c in box.values) c.id: c};
      for (final id in ids) {
        final card = byId[id];
        if (card == null) {
          unknown.add(id);
          continue;
        }
        if (!card.isAcquired) {
          card.recordAcquisition();
          await card.save();
        }
      }
    } else {
      unknown.addAll(ids);
    }
    await flags.put(_pendingCardsKey, unknown);
  }

  Future<void> _put(Map<String, dynamic> payload) async {
    final response = await _client.put('/api/solo/snapshot', payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Snapshot upload failed',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Box> _outbox() async {
    if (!Hive.isBoxOpen(_outboxBox)) {
      return Hive.openBox(_outboxBox);
    }
    return Hive.box(_outboxBox);
  }

  Future<void> _saveOutbox(Map<String, dynamic> payload) async {
    final box = await _outbox();
    await box.put('snapshot', payload);
  }

  Future<void> _clearOutbox() async {
    if (Hive.isBoxOpen(_outboxBox)) {
      await Hive.box(_outboxBox).delete('snapshot');
    }
  }
}

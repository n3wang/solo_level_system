import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:yaml/yaml.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/card_acquisition_service.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

/// Seeds the content-backed card types (`exercise`, `program`, `music`, `room`)
/// from their asset sources so the hub filters aren't empty. A starter subset
/// ships **acquired** (bodyweight exercises, home programs, a few tracks/rooms);
/// the rest start **locked** so the acquired/locked contrast is visible.
///
/// Idempotent: cards are keyed by a stable id and skipped if already present,
/// so re-running never wipes a player's acquisitions.
class CardContentSeedService {
  CardContentSeedService._();

  static const String _boxName = 'motivationItems';
  static const String _workoutsYaml = 'assets/workouts/default_workouts.yaml';
  static const String _set1Yaml = 'assets/workouts/set1_workouts.yaml';
  static const String _roomsYaml = 'assets/lofi/room_music_whitelist.yaml';
  static const String _iconDir = 'assets/icon/workout_icons_sliced';

  /// Default programs that ship LOCKED (must be acquired via a card).
  static const Set<String> _lockedProgramNames = {'legs home'};

  static Future<void> ensureSeeded() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CardModel>(_boxName);
    }
    final box = Hive.box<CardModel>(_boxName);
    await _seedWorkoutCards(box);
    await _seedMusicCards(box);
    await _seedRoomCards(box);
    // Owned rooms (including starters) include their music pack.
    for (final card in box.values) {
      if (card.cardType == CardType.room && card.hasAnyAcquisition) {
        await CardAcquisitionService.grantRoomMusicBundle(card);
      }
    }
  }

  // ---- exercises + programs -------------------------------------------------

  static Future<void> _seedWorkoutCards(Box<CardModel> box) async {
    await _seedExerciseCards(box, _workoutsYaml, acquired: true);
    await _seedExerciseCards(box, _set1Yaml, acquired: false);
    await _seedProgramCards(box, _workoutsYaml);
  }

  static Future<void> _seedExerciseCards(
    Box<CardModel> box,
    String path, {
    required bool acquired,
  }) async {
    try {
      final doc = loadYaml(await rootBundle.loadString(path));
      final exercises = doc['exercises'];
      if (exercises is! YamlList) return;
      final testMode = AppEnvironment.isTest;

      for (final e in exercises) {
        final name = (e['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final description = (e['description'] ?? '').toString().trim();
        final tags = _tags(e['tags']);
        final icon = (e['icon'] ?? '').toString().trim();
        await _add(
          box,
          _makeCard(
            id: 'exercise_${_slug(name)}',
            type: 'exercise',
            title: name,
            description: description.isEmpty ? 'Exercise' : description,
            category: tags.isNotEmpty ? tags.first : 'exercise',
            unlockTargetId: 'exercise:$name',
            pointsCost: testMode ? 5 : 15,
            rarity: acquired ? 'common' : 'rare',
            acquired: acquired,
            imageAsset: icon.isEmpty ? null : '$_iconDir/$icon.png',
          ),
        );
      }
    } catch (_) {
      // Missing/malformed asset must not break the rest of seeding.
    }
  }

  static Future<void> _seedProgramCards(
    Box<CardModel> box,
    String path,
  ) async {
    try {
      final doc = loadYaml(await rootBundle.loadString(path));
      final routines = doc['routines'];
      if (routines is! YamlList) return;
      final testMode = AppEnvironment.isTest;

      for (final r in routines) {
        final name = (r['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final muscle = (r['muscle_group'] ?? '').toString().trim();
        final tags = _tags(r['tags']);
        final exNames = <String>[];
        final rawNames = r['exercise_names'];
        if (rawNames is YamlList) {
          for (final x in rawNames) {
            exNames.add(x.toString());
          }
        }
        final description = [
          if (muscle.isNotEmpty) 'Targets $muscle.',
          if (exNames.isNotEmpty)
            'Includes: ${exNames.take(4).join(', ')}${exNames.length > 4 ? '…' : ''}.',
        ].join(' ');
        final acquired = !_lockedProgramNames.contains(name.toLowerCase());
        await _add(
          box,
          _makeCard(
            id: 'program_${_slug(name)}',
            type: 'program',
            title: name,
            description: description.isEmpty ? 'Workout program' : description,
            category: tags.isNotEmpty ? tags.first : 'program',
            unlockTargetId: 'program:$name',
            pointsCost: testMode ? 10 : 40,
            rarity: acquired ? 'uncommon' : 'rare',
            acquired: acquired,
          ),
        );
      }
    } catch (_) {
      // Missing/malformed asset must not break the rest of seeding.
    }
  }

  // ---- music ----------------------------------------------------------------

  static Future<void> _seedMusicCards(Box<CardModel> box) async {
    try {
      // Includes mapping.json + known room packs (ghost_lofi, like_a_dog, …).
      final tracks = await LofiService.getAllTracks();
      final testMode = AppEnvironment.isTest;

      var index = 0;
      for (final t in tracks) {
        final filename = t.filename.trim();
        if (filename.isEmpty) continue;
        final albumImage = (t.albumImage ?? '').trim();
        final acquired = index < 3;
        await _add(
          box,
          _makeCard(
            id: 'music_${t.id}',
            type: 'music',
            title: t.title,
            description: t.author.trim().isEmpty
                ? 'Lofi track'
                : 'by ${t.author}',
            category: 'lofi',
            unlockTargetId: 'music:$filename',
            pointsCost: testMode ? 5 : 20,
            rarity: 'common',
            acquired: acquired,
            imageAsset: albumImage.isEmpty ? null : 'assets/$albumImage',
          ),
        );
        index++;
      }
    } catch (_) {
      // ignore
    }
  }

  // ---- rooms ----------------------------------------------------------------

  static Future<void> _seedRoomCards(Box<CardModel> box) async {
    try {
      final doc = loadYaml(await rootBundle.loadString(_roomsYaml));
      final rooms = doc['rooms'];
      if (rooms is! YamlList) return;
      final testMode = AppEnvironment.isTest;

      final trackFilenames = <String>[];
      try {
        final tracks = await LofiService.getAllTracks();
        for (final t in tracks) {
          if (t.filename.isNotEmpty) trackFilenames.add(t.filename);
        }
      } catch (_) {
        // optional
      }

      var index = 0;
      for (final r in rooms) {
        final id = (r['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final name = (r['name'] ?? id).toString();
        final description = (r['description'] ?? '').toString().trim();
        final iconAssetPath = (r['iconAssetPath'] ?? '').toString().trim();
        final trackRegexRaw = (r['trackRegex'] ?? '').toString().trim();
        final visuals = <String>[];
        final rawVisuals = r['visuals'];
        if (rawVisuals is YamlList) {
          for (final v in rawVisuals) {
            final path = v.toString().trim();
            if (path.isNotEmpty) visuals.add(path);
          }
        }

        var bundledMusicCount = 0;
        if (trackRegexRaw.isNotEmpty) {
          try {
            final regex = RegExp(trackRegexRaw);
            bundledMusicCount = trackFilenames.where(regex.hasMatch).length;
          } catch (_) {
            bundledMusicCount = 0;
          }
        }

        final acquired = index < 2;
        await _add(
          box,
          _makeCard(
            id: 'room_${_slug(id)}',
            type: 'room',
            title: name,
            description: description.isEmpty ? 'Room atmosphere' : description,
            category: 'room',
            unlockTargetId: 'room:${_slug(id)}',
            pointsCost: testMode ? 10 : 35,
            rarity: 'uncommon',
            acquired: acquired,
            imageAsset: iconAssetPath.isEmpty ? null : iconAssetPath,
            visuals: visuals,
            trackRegex: trackRegexRaw.isEmpty ? null : trackRegexRaw,
            bundledMusicCount: bundledMusicCount,
          ),
        );
        index++;
      }
    } catch (_) {
      // ignore
    }
  }

  // ---- helpers --------------------------------------------------------------

  static List<String> _tags(dynamic raw) {
    if (raw is YamlList) {
      return raw.map((t) => t.toString().toLowerCase()).toList();
    }
    return const [];
  }

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static CardModel _makeCard({
    required String id,
    required String type,
    required String title,
    required String description,
    required String category,
    required String unlockTargetId,
    required int pointsCost,
    required String rarity,
    required bool acquired,
    String? imageAsset,
    List<String> visuals = const [],
    String? trackRegex,
    int bundledMusicCount = 0,
  }) {
    final now = DateTime.now();
    return CardModel(
      id: id,
      type: type,
      title: title,
      description: description,
      category: category,
      pointsCost: pointsCost,
      createdAt: now,
      isSystem: true,
      isStarter: acquired,
      isAcquired: acquired,
      acquisitionCount: acquired ? 1 : 0,
      acquisitionHistory: acquired ? [now] : const [],
      unlockTargetId: unlockTargetId,
      rarity: rarity,
      metadata: {
        'source': 'content_seed',
        if (imageAsset != null) 'imageAsset': imageAsset,
        if (visuals.isNotEmpty) 'visuals': visuals,
        if (trackRegex != null) 'trackRegex': trackRegex,
        if (bundledMusicCount > 0) 'bundledMusicCount': bundledMusicCount,
      },
    );
  }

  static Future<void> _add(Box<CardModel> box, CardModel card) async {
    CardModel? existing;
    for (final c in box.values) {
      if (c.id == card.id) {
        existing = c;
        break;
      }
    }
    if (existing == null) {
      await box.add(card);
      return;
    }

    if (existing.metadata['source'] != 'content_seed') return;
    var changed = false;
    final nextMeta = Map<String, dynamic>.from(existing.metadata);

    void backfill(String key) {
      final next = card.metadata[key];
      if (next == null) return;
      final cur = existing!.metadata[key];
      if (cur == null ||
          (cur is List && cur.isEmpty) ||
          (cur is String && cur.isEmpty)) {
        nextMeta[key] = next;
        changed = true;
      }
    }

    backfill('imageAsset');
    backfill('visuals');
    backfill('trackRegex');
    backfill('bundledMusicCount');
    if (changed) {
      existing.metadata = nextMeta;
    }

    if (existing.unlockTargetId != card.unlockTargetId) {
      existing.unlockTargetId = card.unlockTargetId;
      changed = true;
    }

    if (!existing.isAcquired &&
        existing.acquisitionCount == 0 &&
        card.isAcquired) {
      existing.isStarter = true;
      existing.isAcquired = true;
      existing.acquisitionCount = 1;
      existing.acquisitionHistory = card.acquisitionHistory;
      changed = true;
    }

    if (existing.isStarter &&
        existing.acquisitionCount <= 1 &&
        !card.isAcquired) {
      existing.isStarter = false;
      existing.isAcquired = false;
      existing.acquisitionCount = 0;
      existing.acquisitionHistory = const [];
      changed = true;
    }

    if (changed) await existing.save();
  }
}

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:yaml/yaml.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/utils/card_acquisition_service.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

/// Seeds the content-backed card types (`exercise`, `music`, `room`) from their
/// asset sources so the hub filters aren't empty. A starter subset ships
/// **acquired** (bodyweight exercises, a few tracks/rooms); the rest start
/// **locked** so the acquired/locked contrast is visible.
///
/// Idempotent: cards are keyed by a stable id and skipped if already present,
/// so re-running never wipes a player's acquisitions.
class CardContentSeedService {
  CardContentSeedService._();

  static const String _boxName = 'motivationItems';
  static const String _workoutsYaml = 'assets/data/default_workouts.yaml';
  static const String _roomsYaml = 'assets/data/rooms.yml';
  static const String _iconDir = 'assets/images/icon/workout_icons_sliced';


  static Future<void> ensureSeeded() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CardModel>(_boxName);
    }
    final box = Hive.box<CardModel>(_boxName);
    await _cleanupOldRoutineCards(box);
    await _seedWorkoutCards(box);
    await _seedTimedProgramCards(box);
    await _seedMusicCards(box);
    await _seedRoomCards(box);
    // Owned rooms (including starters) include their music pack.
    for (final card in box.values) {
      if (card.cardType == CardType.room && card.hasAnyAcquisition) {
        await CardAcquisitionService.grantRoomMusicBundle(card);
      }
    }
  }

  /// Remove old routine cards (Chest Day, Arms Day, etc.) that were incorrectly seeded.
  static Future<void> _cleanupOldRoutineCards(Box<CardModel> box) async {
    final toRemove = <CardModel>[];
    for (final card in box.values) {
      if (card.id.startsWith('program_') &&
          card.metadata['source'] == 'content_seed') {
        toRemove.add(card);
      }
    }
    for (final card in toRemove) {
      await card.delete();
    }
  }

  // ---- exercises ------------------------------------------------------------

  static Future<void> _seedWorkoutCards(Box<CardModel> box) async {
    await _seedExerciseCards(box, _workoutsYaml);
  }

  // ---- timed programs (7 Minute Workout, etc.) ------------------------------

  /// Seeds cards for timed workout programs from the timedWorkouts box.
  /// These appear under the 'exercise' type filter with isProgram=true metadata.
  static Future<void> _seedTimedProgramCards(Box<CardModel> box) async {
    try {
      if (!Hive.isBoxOpen('timedWorkouts')) {
        await Hive.openBox<TimedWorkoutModel>('timedWorkouts');
      }
      final programsBox = Hive.box<TimedWorkoutModel>('timedWorkouts');
      if (programsBox.isEmpty) return;

      Box<ExerciseModel>? exercisesBox;
      try {
        if (!Hive.isBoxOpen('exercises')) {
          await Hive.openBox<ExerciseModel>('exercises');
        }
        exercisesBox = Hive.box<ExerciseModel>('exercises');
      } catch (_) {
        // Optional - proceed without exercise images
      }

      final testMode = AppEnvironment.isTest;

      for (final program in programsBox.values) {
        if (program.name.isEmpty) continue;

        // Get first 3 non-break exercise images for the card preview
        final exerciseImages = <String>[];
        if (exercisesBox != null) {
          for (final item in program.workoutOrder) {
            if (exerciseImages.length >= 3) break;
            final exercise = exercisesBox.get(item.workoutId) ??
                exercisesBox.values.cast<ExerciseModel?>().firstWhere(
                      (ex) => ex?.id == item.workoutId,
                      orElse: () => null,
                    );
            if (exercise == null) continue;
            final name = exercise.name.toLowerCase();
            if (name == 'break' || name == 'rest') continue;
            if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) {
              exerciseImages.add(exercise.imageUrl!);
            }
          }
        }

        // Aerobics programs start locked; others unlocked
        final nameLower = program.name.toLowerCase();
        final isAerobics = nameLower.contains('aerobic');
        final acquired = !isAerobics;

        await _add(
          box,
          _makeProgramCard(
            id: 'timed_program_${_slug(program.id)}',
            title: program.name,
            description: program.formattedDuration,
            unlockTargetId: 'program:${program.name}',
            pointsCost: testMode ? 10 : (isAerobics ? 60 : 40),
            rarity: isAerobics ? 'rare' : 'uncommon',
            acquired: acquired,
            exerciseImages: exerciseImages,
            durationSeconds: program.totalDuration,
          ),
        );
      }
    } catch (_) {
      // Programs box may not exist yet - that's fine
    }
  }

  static CardModel _makeProgramCard({
    required String id,
    required String title,
    required String description,
    required String unlockTargetId,
    required int pointsCost,
    required String rarity,
    required bool acquired,
    List<String> exerciseImages = const [],
    int durationSeconds = 0,
  }) {
    final now = DateTime.now();
    return CardModel(
      id: id,
      type: 'exercise',
      title: title,
      description: description,
      category: 'exercise',
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
        'isProgram': true,
        'durationSeconds': durationSeconds,
        if (exerciseImages.isNotEmpty) 'exerciseImages': exerciseImages,
      },
    );
  }

  static Future<void> _seedExerciseCards(
    Box<CardModel> box,
    String path,
  ) async {
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
        final acquired = e['starter'] != false;
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
            imageAsset: albumImage.isEmpty ? null : 'assets/images/$albumImage',
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

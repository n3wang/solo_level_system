// lib/utils/default_workouts_service.dart
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:yaml/yaml.dart';
import '../models/exercise_model.dart';
import '../models/workout_routine_model.dart';
import '../models/workout_set_model.dart';
import 'exercise_tag_semantics.dart';

/// Service for initializing default workouts on first app install
class DefaultWorkoutsService {
  static const String _defaultWorkoutsInitializedKey =
      'default_workouts_initialized';
  static const String _appFlagsBoxName = 'app_init_flags';

  /// Check if default workouts have been initialized
  static Future<bool> areDefaultWorkoutsInitialized() async {
    try {
      if (!Hive.isBoxOpen(_appFlagsBoxName)) {
        await Hive.openBox(_appFlagsBoxName);
      }
      final flagsBox = Hive.box(_appFlagsBoxName);
      return flagsBox.get(_defaultWorkoutsInitializedKey, defaultValue: false)
          as bool;
    } catch (e) {
      print('Error checking default workouts status: $e');
      return false;
    }
  }

  /// Mark default workouts as initialized
  static Future<void> markDefaultWorkoutsInitialized() async {
    try {
      if (!Hive.isBoxOpen(_appFlagsBoxName)) {
        await Hive.openBox(_appFlagsBoxName);
      }
      final flagsBox = Hive.box(_appFlagsBoxName);
      await flagsBox.put(_defaultWorkoutsInitializedKey, true);
    } catch (e) {
      print('Error marking default workouts as initialized: $e');
    }
  }

  /// Initialize all default workouts and exercises
  static Future<void> initializeDefaultWorkouts() async {
    try {
      // Check if already initialized
      if (await areDefaultWorkoutsInitialized()) {
        print('Default workouts already initialized');
        return;
      }

      // Ensure boxes are open
      if (!Hive.isBoxOpen('exercises')) {
        await Hive.openBox<ExerciseModel>('exercises');
      }
      if (!Hive.isBoxOpen('workoutRoutines')) {
        await Hive.openBox<WorkoutRoutineModel>('workoutRoutines');
      }

      final exercisesBox = Hive.box<ExerciseModel>('exercises');
      final routinesBox = Hive.box<WorkoutRoutineModel>('workoutRoutines');

      // Create all default exercises
      final exercises = await _createDefaultExercises();
      final exerciseMap = <String, ExerciseModel>{};

      for (final exercise in exercises) {
        await exercisesBox.put(exercise.id, exercise);
        // Store with multiple keys for flexible lookup (case-insensitive)
        final nameLower = exercise.name.toLowerCase().trim();
        exerciseMap[nameLower] = exercise;
        exerciseMap[exercise.name] = exercise;
        exerciseMap[exercise.name.trim()] = exercise;
      }

      // Create default routines grouped by muscle groups
      final routines = await _createDefaultRoutines(exerciseMap);

      for (final routine in routines) {
        await routinesBox.put(routine.id, routine);
      }

      // Mark as initialized
      await markDefaultWorkoutsInitialized();

      print(
        '✓ Default workouts initialized: ${exercises.length} exercises, ${routines.length} routines',
      );
    } catch (e) {
      print('Error initializing default workouts: $e');
      rethrow;
    }
  }

  static const String _yamlPath = 'assets/workouts/default_workouts.yaml';
  static const String _set1YamlPath = 'assets/workouts/set1_workouts.yaml';

  /// All exercise-source YAMLs. `default_workouts.yaml` exercises unlock by
  /// default; `set1_workouts.yaml` exercises ship locked (card-gated). Both are
  /// loaded so the ExerciseModel exists and can appear once its card is acquired.
  static const List<String> _exerciseYamlPaths = [_yamlPath, _set1YamlPath];

  /// Create all default exercises from every source YAML
  static Future<List<ExerciseModel>> _createDefaultExercises() async {
    final now = DateTime.now();
    final exercises = <ExerciseModel>[];
    var idCounter = 0;

    for (final path in _exerciseYamlPaths) {
      try {
        final String yamlString = await rootBundle.loadString(path);
        final dynamic yamlMap = loadYaml(yamlString);

        if (yamlMap is! Map) continue;

        final exercisesList = yamlMap['exercises'] as YamlList?;
        if (exercisesList == null) continue;

        for (int i = 0; i < exercisesList.length; i++) {
          idCounter++;
          final exerciseData = exercisesList[i] as Map;

          final name = exerciseData['name']?.toString() ?? '';
        final icon = exerciseData['icon']?.toString();
        final description = exerciseData['description']?.toString() ?? '';
        final instructions =
            (exerciseData['instructions'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final rawTags =
            (exerciseData['tags'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Backward-compatible: if YAML still has legacy fields, fold into tags.
        final resolved = ExerciseTagSemantics.resolve(
          ExerciseTagSemantics.buildTags(
            existing: rawTags,
            category: exerciseData['category']?.toString(),
            muscleGroup: exerciseData['muscle_group']?.toString(),
            equipment: exerciseData['equipment']?.toString(),
            difficulty: exerciseData['difficulty']?.toString(),
          ),
        );

        // Determine measurement unit based on exercise characteristics
        String measurementUnit = 'kg'; // Default to kg
        final defaultDuration = exerciseData['default_duration'] as int?;
        final equipmentLower = resolved.equipment.toLowerCase();
        final nameLower = name.toLowerCase();

        // Time-based exercises (plank, wall sit, etc.)
        if (defaultDuration != null ||
            nameLower.contains('plank') ||
            nameLower.contains('hold') ||
            nameLower.contains('wall sit')) {
          measurementUnit = 'seconds';
        }
        // Bodyweight exercises with no weight tracking
        else if (equipmentLower == 'bodyweight' &&
            !nameLower.contains('weighted') &&
            !nameLower.contains('dumbbell') &&
            !nameLower.contains('barbell')) {
          measurementUnit = 'none';
        }

        // Try to get audio file from YAML, or generate it from name
        final audioFile = exerciseData['audio_file']?.toString();

        final exercise = ExerciseModel(
          id: 'default_exercise_$idCounter',
          name: name,
          description: description,
          category: resolved.category,
          muscleGroup: resolved.muscleGroup,
          equipment: resolved.equipment,
          difficulty: resolved.difficulty,
          instructions: instructions.isNotEmpty
              ? instructions
              : [
                  'Perform with proper form',
                  'Control the movement throughout',
                  'Breathe properly during execution',
                ],
          imageUrl: icon,
          isCustom: false,
          createdAt: now,
          tags: resolved.tags,
          measurementUnit: measurementUnit,
          audioFile: audioFile,
        );
        exercises.add(exercise);
        }
      } catch (e) {
        print('Error loading exercises from $path: $e');
      }
    }

    return exercises;
  }

  /// Create default routines grouped by muscle groups from YAML
  static Future<List<WorkoutRoutineModel>> _createDefaultRoutines(
    Map<String, ExerciseModel> exerciseMap,
  ) async {
    final now = DateTime.now();
    final routines = <WorkoutRoutineModel>[];

    try {
      // Load YAML file
      final String yamlString = await rootBundle.loadString(_yamlPath);
      final dynamic yamlMap = loadYaml(yamlString);

      if (yamlMap is! Map) {
        throw Exception('Invalid YAML format: root must be a map');
      }

      final routinesList = yamlMap['routines'] as YamlList?;
      if (routinesList == null) {
        throw Exception('Missing routines list in YAML');
      }

      for (int i = 0; i < routinesList.length; i++) {
        final routineData = routinesList[i] as Map;

        final routineName = routineData['name']?.toString() ?? '';
        final muscleGroup = routineData['muscle_group']?.toString() ?? '';
        final exerciseNames =
            (routineData['exercise_names'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final tags =
            (routineData['tags'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final setNumbers =
            (routineData['set_numbers'] as YamlList?)
                ?.map((e) => e as int)
                .toList() ??
            [1, 2, 3];

        // Find exercises (case-insensitive matching)
        final exerciseIds = <String>[];
        final exerciseSets = <String, List<WorkoutSetModel>>{};

        for (final exerciseName in exerciseNames) {
          // Try multiple matching strategies (case-insensitive)
          final normalizedName = exerciseName.trim().toLowerCase();
          ExerciseModel? exercise =
              exerciseMap[normalizedName] ??
              exerciseMap[exerciseName.trim()] ??
              exerciseMap[exerciseName];

          // If still not found, try case-insensitive search
          if (exercise == null) {
            for (final key in exerciseMap.keys) {
              if (key.toLowerCase() == normalizedName) {
                exercise = exerciseMap[key];
                break;
              }
            }
          }

          if (exercise != null) {
            exerciseIds.add(exercise.id);

            // Get default sets/reps from exercise YAML data
            final exerciseYamlData = await _getExerciseYamlData(exercise.name);
            final defaultSets =
                (exerciseYamlData['default_sets'] as YamlList?)
                    ?.map((e) => e as int)
                    .toList() ??
                setNumbers;
            final defaultReps = exerciseYamlData['default_reps'] as int? ?? 10;
            final defaultDuration =
                exerciseYamlData['default_duration'] as int?;

            // Create sets based on set numbers
            final sets = <WorkoutSetModel>[];
            for (final setNum in setNumbers) {
              if (defaultSets.contains(setNum)) {
                // Determine measurement type and value
                String measurementType = exercise.measurementUnit;
                double? value;

                if (measurementType == 'seconds') {
                  value = defaultDuration?.toDouble();
                } else if (measurementType == 'none') {
                  value = null;
                } else {
                  value = exercise.equipment != 'bodyweight' ? 0.0 : null;
                }

                sets.add(
                  WorkoutSetModel(
                    id: '${exercise.id}_set_$setNum',
                    exerciseId: exercise.id,
                    reps: defaultReps,
                    measurementType: measurementType,
                    value: value,
                    restTimeSeconds: 60,
                    isCompleted: false,
                  ),
                );
              }
            }
            exerciseSets[exercise.id] = sets;
          }
        }

        if (exerciseIds.isNotEmpty) {
          final routine = WorkoutRoutineModel(
            id: 'default_routine_${i + 1}',
            name: routineName,
            description:
                'Default $muscleGroup workout routine with ${exerciseIds.length} exercises',
            exerciseIds: exerciseIds,
            exerciseSets: exerciseSets,
            category: 'strength',
            difficulty: 'intermediate',
            estimatedDurationMinutes: exerciseIds.length * 15,
            tags: tags,
            isTemplate: true,
            isFavorite: false,
            createdAt: now,
            targetMuscleGroups: [muscleGroup],
            createdBy: 'system',
          );
          routines.add(routine);
        }
      }
    } catch (e) {
      print('Error loading routines from YAML: $e');
      rethrow;
    }

    return routines;
  }

  /// Get exercise data from YAML by name (case-insensitive)
  static Future<Map<dynamic, dynamic>> _getExerciseYamlData(
    String exerciseName,
  ) async {
    try {
      final String yamlString = await rootBundle.loadString(_yamlPath);
      final dynamic yamlMap = loadYaml(yamlString);
      final exercisesList = yamlMap['exercises'] as YamlList?;

      if (exercisesList != null) {
        for (final exerciseData in exercisesList) {
          final name = (exerciseData as Map)['name']?.toString() ?? '';
          if (name.toLowerCase().trim() == exerciseName.toLowerCase().trim()) {
            return exerciseData;
          }
        }
      }
    } catch (e) {
      print('Error getting exercise YAML data: $e');
    }
    return {};
  }

  /// Update all existing exercises' audioFile from YAML
  /// Call this to sync audio files without full re-initialization
  static Future<int> updateAudioFilesFromYaml() async {
    print('[AudioSync] Starting audio file sync from YAML...');
    int updatedCount = 0;
    try {
      // Ensure exercises box is open
      if (!Hive.isBoxOpen('exercises')) {
        print('[AudioSync] Opening exercises box...');
        await Hive.openBox<ExerciseModel>('exercises');
      }
      final exercisesBox = Hive.box<ExerciseModel>('exercises');
      print('[AudioSync] Exercises box has ${exercisesBox.length} exercises');

      // Load audio files from YAML
      print('[AudioSync] Loading YAML from $_yamlPath');
      final String yamlString = await rootBundle.loadString(_yamlPath);
      final dynamic yamlMap = loadYaml(yamlString);
      final exercisesList = yamlMap['exercises'] as YamlList?;

      if (exercisesList == null) {
        print('[AudioSync] ✗ No exercises list found in YAML');
        return 0;
      }
      print('[AudioSync] Found ${exercisesList.length} exercises in YAML');

      // Build a map of exercise name (lowercase) -> audio_file
      final audioMap = <String, String>{};
      for (final exerciseData in exercisesList) {
        final name = (exerciseData as Map)['name']?.toString() ?? '';
        final audioFile = exerciseData['audio_file']?.toString();
        if (name.isNotEmpty && audioFile != null && audioFile.isNotEmpty) {
          audioMap[name.toLowerCase().trim()] = audioFile;
        }
      }
      print('[AudioSync] Built audio map with ${audioMap.length} entries');

      // Debug: Check if Jumping Jacks is in the map
      if (audioMap.containsKey('jumping jacks')) {
        print('[AudioSync] ✓ "jumping jacks" found in audioMap: "${audioMap['jumping jacks']}"');
      } else {
        print('[AudioSync] ✗ "jumping jacks" NOT found in audioMap');
        print('[AudioSync] Available keys: ${audioMap.keys.take(10).toList()}...');
      }

      // Update existing exercises
      for (final exercise in exercisesBox.values) {
        final normalizedName = exercise.name.toLowerCase().trim();
        final yamlAudioFile = audioMap[normalizedName];

        // Debug specific exercises
        if (normalizedName == 'jumping jacks') {
          print('[AudioSync] Found "Jumping Jacks" in Hive:');
          print('[AudioSync]   - ID: ${exercise.id}');
          print('[AudioSync]   - Current audioFile: "${exercise.audioFile}"');
          print('[AudioSync]   - YAML audioFile: "$yamlAudioFile"');
        }

        if (yamlAudioFile != null && exercise.audioFile != yamlAudioFile) {
          print(
            '[AudioSync] Updating "${exercise.name}" audioFile: '
            '"${exercise.audioFile}" -> "$yamlAudioFile"',
          );
          exercise.audioFile = yamlAudioFile;
          await exercise.save();
          updatedCount++;
        }
      }

      print('[AudioSync] ✓ Sync complete. Updated $updatedCount exercises');
    } catch (e, stack) {
      print('[AudioSync] ✗ Error updating audio files from YAML: $e');
      print('[AudioSync] Stack: $stack');
    }
    return updatedCount;
  }

  /// Delete all default workouts (for reset/testing)
  static Future<void> deleteDefaultWorkouts() async {
    try {
      if (!Hive.isBoxOpen('exercises')) {
        await Hive.openBox<ExerciseModel>('exercises');
      }
      if (!Hive.isBoxOpen('workoutRoutines')) {
        await Hive.openBox<WorkoutRoutineModel>('workoutRoutines');
      }

      final exercisesBox = Hive.box<ExerciseModel>('exercises');
      final routinesBox = Hive.box<WorkoutRoutineModel>('workoutRoutines');

      // Delete all default exercises
      final exercises = exercisesBox.values.where((e) => !e.isCustom).toList();
      for (final exercise in exercises) {
        await exercise.delete();
      }

      // Delete all default routines
      final routines = routinesBox.values
          .where((r) => r.createdBy == 'system')
          .toList();
      for (final routine in routines) {
        await routine.delete();
      }

      // Reset initialization flag
      if (!Hive.isBoxOpen(_appFlagsBoxName)) {
        await Hive.openBox(_appFlagsBoxName);
      }
      final flagsBox = Hive.box(_appFlagsBoxName);
      await flagsBox.put(_defaultWorkoutsInitializedKey, false);

      print('✓ Default workouts deleted');
    } catch (e) {
      print('Error deleting default workouts: $e');
      rethrow;
    }
  }
}

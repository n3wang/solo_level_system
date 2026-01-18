// lib/utils/default_workouts_service.dart
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:yaml/yaml.dart';
import '../models/exercise_model.dart';
import '../models/workout_routine_model.dart';
import '../models/workout_set_model.dart';

/// Service for initializing default workouts on first app install
class DefaultWorkoutsService {
  static const String _defaultWorkoutsInitializedKey =
      'default_workouts_initialized';

  /// Check if default workouts have been initialized
  static Future<bool> areDefaultWorkoutsInitialized() async {
    try {
      if (!Hive.isBoxOpen('config')) {
        await Hive.openBox('config');
      }
      final configBox = Hive.box('config');
      return configBox.get(_defaultWorkoutsInitializedKey, defaultValue: false)
          as bool;
    } catch (e) {
      print('Error checking default workouts status: $e');
      return false;
    }
  }

  /// Mark default workouts as initialized
  static Future<void> markDefaultWorkoutsInitialized() async {
    try {
      if (!Hive.isBoxOpen('config')) {
        await Hive.openBox('config');
      }
      final configBox = Hive.box('config');
      await configBox.put(_defaultWorkoutsInitializedKey, true);
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

  /// Create all default exercises from YAML
  static Future<List<ExerciseModel>> _createDefaultExercises() async {
    final now = DateTime.now();
    final exercises = <ExerciseModel>[];

    try {
      // Load YAML file
      final String yamlString = await rootBundle.loadString(_yamlPath);
      final dynamic yamlMap = loadYaml(yamlString);

      if (yamlMap is! Map) {
        throw Exception('Invalid YAML format: root must be a map');
      }

      final exercisesList = yamlMap['exercises'] as YamlList?;
      if (exercisesList == null) {
        throw Exception('Missing exercises list in YAML');
      }

      for (int i = 0; i < exercisesList.length; i++) {
        final exerciseData = exercisesList[i] as Map;

        final name = exerciseData['name']?.toString() ?? '';
        final muscleGroup = exerciseData['muscle_group']?.toString() ?? '';
        final equipment = exerciseData['equipment']?.toString() ?? '';
        final category = exerciseData['category']?.toString() ?? '';
        final difficulty = exerciseData['difficulty']?.toString() ?? '';
        final spriteIndex = exerciseData['sprite_index'] as int? ?? 0;
        final description = exerciseData['description']?.toString() ?? '';
        final instructions =
            (exerciseData['instructions'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final tags =
            (exerciseData['tags'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final exercise = ExerciseModel(
          id: 'default_exercise_${i + 1}',
          name: name,
          description: description,
          category: category,
          muscleGroup: muscleGroup,
          equipment: equipment,
          difficulty: difficulty,
          instructions: instructions.isNotEmpty
              ? instructions
              : [
                  'Perform with proper form',
                  'Control the movement throughout',
                  'Breathe properly during execution',
                ],
          imageUrl: 'workout_sprite_$spriteIndex',
          isCustom: false,
          createdAt: now,
          tags: tags,
        );
        exercises.add(exercise);
      }
    } catch (e) {
      print('Error loading exercises from YAML: $e');
      rethrow;
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
                exerciseYamlData['default_sets'] as List<int>? ?? setNumbers;
            final defaultReps = exerciseYamlData['default_reps'] as int? ?? 10;
            final defaultDuration =
                exerciseYamlData['default_duration'] as int?;

            // Create sets based on set numbers
            final sets = <WorkoutSetModel>[];
            for (final setNum in setNumbers) {
              if (defaultSets.contains(setNum)) {
                sets.add(
                  WorkoutSetModel(
                    id: '${exercise.id}_set_$setNum',
                    exerciseId: exercise.id,
                    reps: defaultReps,
                    duration: defaultDuration,
                    weight: exercise.equipment != 'bodyweight' ? 0.0 : null,
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
                'Default ${muscleGroup} workout routine with ${exerciseIds.length} exercises',
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
      if (!Hive.isBoxOpen('config')) {
        await Hive.openBox('config');
      }
      final configBox = Hive.box('config');
      await configBox.put(_defaultWorkoutsInitializedKey, false);

      print('✓ Default workouts deleted');
    } catch (e) {
      print('Error deleting default workouts: $e');
      rethrow;
    }
  }
}

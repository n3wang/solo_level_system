// lib/utils/programs_service.dart
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:yaml/yaml.dart';
import '../models/exercise_model.dart';
import '../models/timed_workout_model.dart';

/// Service for initializing 7-minute workout programs and exercises
class ProgramsService {
  static const String _programsInitializedKey = 'programs_initialized';
  static const String _yamlPath = 'assets/workouts/default_workouts.yaml';

  /// Check if programs have been initialized
  static Future<bool> areProgramsInitialized() async {
    try {
      if (!Hive.isBoxOpen('config')) {
        await Hive.openBox('config');
      }
      final configBox = Hive.box('config');
      return configBox.get(_programsInitializedKey, defaultValue: false)
          as bool;
    } catch (e) {
      print('Error checking programs status: $e');
      return false;
    }
  }

  /// Mark programs as initialized
  static Future<void> markProgramsInitialized() async {
    try {
      if (!Hive.isBoxOpen('config')) {
        await Hive.openBox('config');
      }
      final configBox = Hive.box('config');
      await configBox.put(_programsInitializedKey, true);
    } catch (e) {
      print('Error marking programs as initialized: $e');
    }
  }

  /// Initialize all 7-minute workout programs and exercises
  static Future<void> initializePrograms() async {
    try {
      // Check if already initialized
      if (await areProgramsInitialized()) {
        print('Programs already initialized');
        return;
      }

      // Ensure boxes are open
      if (!Hive.isBoxOpen('exercises')) {
        await Hive.openBox<ExerciseModel>('exercises');
      }
      if (!Hive.isBoxOpen('timedWorkouts')) {
        await Hive.openBox<TimedWorkoutModel>('timedWorkouts');
      }

      final exercisesBox = Hive.box<ExerciseModel>('exercises');
      final programsBox = Hive.box<TimedWorkoutModel>('timedWorkouts');

      final now = DateTime.now();

      // Helper function to find or create exercise
      ExerciseModel? _findOrCreateExercise(
        String name,
        Map<String, ExerciseModel> existingMap,
      ) {
        // Try to find existing exercise by name (case-insensitive)
        for (final existing in exercisesBox.values) {
          if (existing.name.toLowerCase() == name.toLowerCase()) {
            return existing;
          }
        }
        return null;
      }

      // Create Break exercise if it doesn't exist
      print('[ProgramsService] Checking for Break exercise...');
      ExerciseModel breakExercise;
      final existingBreak = _findOrCreateExercise('Break', {});
      if (existingBreak != null) {
        print('[ProgramsService] Break exercise already exists');
        print(
          '[ProgramsService]   - Existing audioFile: "${existingBreak.audioFile}"',
        );
        breakExercise = existingBreak;
        // Ensure break exercise has audioFile set
        if (breakExercise.audioFile == null ||
            breakExercise.audioFile!.isEmpty) {
          print(
            '[ProgramsService]   ✗ Break exercise has no audioFile, setting to: "audio/break_time.mp3"',
          );
          breakExercise.audioFile = 'audio/break_time.mp3';
          breakExercise.save();
          print('[ProgramsService]   ✓ Updated break exercise audioFile');
        } else {
          print(
            '[ProgramsService]   ✓ Break exercise already has audioFile: "${breakExercise.audioFile}"',
          );
        }
      } else {
        print('[ProgramsService] Creating new Break exercise');
        breakExercise = _createBreakExercise(now);
        print(
          '[ProgramsService]   - New break exercise audioFile: "${breakExercise.audioFile}"',
        );
        await exercisesBox.put(breakExercise.id, breakExercise);
        print('[ProgramsService]   ✓ Saved new Break exercise to box');
      }

      // Get audio files from YAML
      final yamlAudioMap = await _getAudioFilesFromYaml();

      // Create all exercises from the 7-minute workout
      final exercises = await _create7MinuteWorkoutExercises(now);
      final exerciseMap = <String, ExerciseModel>{};

      // First, map all existing exercises
      for (final existing in exercisesBox.values) {
        exerciseMap[existing.name.toLowerCase()] = existing;
        exerciseMap[existing.name] = existing;
      }

      // Then, create new exercises that don't exist
      for (final exercise in exercises) {
        print('[ProgramsService] Processing exercise: "${exercise.name}"');
        final existing = _findOrCreateExercise(exercise.name, exerciseMap);
        if (existing == null) {
          print('[ProgramsService] Creating NEW exercise: "${exercise.name}"');
          // Use audio file from YAML if available
          final yamlAudioFile = yamlAudioMap[exercise.name.toLowerCase()];
          final audioFile = yamlAudioFile ?? exercise.audioFile;

          print(
            '[ProgramsService]   - audioFile from hardcoded data: "${exercise.audioFile}"',
          );
          print(
            '[ProgramsService]   - audioFile from YAML: "${yamlAudioFile}"',
          );
          print('[ProgramsService]   - Final audioFile to use: "$audioFile"');

          if (audioFile != null && audioFile != exercise.audioFile) {
            exercise.audioFile = audioFile;
            print(
              '[ProgramsService]   ✓ Updated exercise audioFile to: "$audioFile"',
            );
          }
          await exercisesBox.put(exercise.id, exercise);
          exerciseMap[exercise.name.toLowerCase()] = exercise;
          exerciseMap[exercise.name] = exercise;
        } else {
          print(
            '[ProgramsService] Exercise ALREADY EXISTS: "${exercise.name}"',
          );
          print(
            '[ProgramsService]   - Existing audioFile: "${existing.audioFile}"',
          );
          // Update existing exercise's audioFile from YAML if available
          final yamlAudioFile = yamlAudioMap[exercise.name.toLowerCase()];
          print('[ProgramsService]   - audioFile from YAML: "$yamlAudioFile"');

          if (yamlAudioFile != null && existing.audioFile != yamlAudioFile) {
            print(
              '[ProgramsService]   ✓ Updating existing exercise audioFile from "${existing.audioFile}" to "$yamlAudioFile"',
            );
            existing.audioFile = yamlAudioFile;
            existing.save();
          } else if (yamlAudioFile == null) {
            print(
              '[ProgramsService]   ✗ No audioFile found in YAML for "${exercise.name}"',
            );
          } else {
            print(
              '[ProgramsService]   - audioFile already matches YAML, no update needed',
            );
          }
          exerciseMap[exercise.name.toLowerCase()] = existing;
          exerciseMap[exercise.name] = existing;
        }
        // Also store variations for matching
        if (exercise.name.contains(' ')) {
          final key = exercise.name.toLowerCase().replaceAll(' ', '-');
          if (!exerciseMap.containsKey(key)) {
            exerciseMap[key] = existing ?? exercise;
          }
        }
        if (exercise.name.contains('+')) {
          final key = exercise.name.toLowerCase().replaceAll('+', ' ').trim();
          if (!exerciseMap.containsKey(key)) {
            exerciseMap[key] = existing ?? exercise;
          }
        }
      }

      // Create 2 7-minute workout programs
      final programs = _create7MinuteWorkoutPrograms(
        now,
        exerciseMap,
        breakExercise,
      );

      for (final program in programs) {
        await programsBox.put(program.id, program);
      }

      // Mark as initialized
      await markProgramsInitialized();

      final exercisesList = await exercises;
      print(
        '✓ Programs initialized: ${exercisesList.length + 1} exercises, ${programs.length} programs',
      );
    } catch (e) {
      print('Error initializing programs: $e');
      rethrow;
    }
  }

  /// Get audio files from default_workouts.yaml
  static Future<Map<String, String>> _getAudioFilesFromYaml() async {
    final audioMap = <String, String>{};
    try {
      final String yamlString = await rootBundle.loadString(_yamlPath);
      final dynamic yamlMap = loadYaml(yamlString) as Map;
      final exercisesList = yamlMap['exercises'];

      if (exercisesList != null) {
        for (final exerciseData in exercisesList) {
          final name = (exerciseData as Map)['name']?.toString() ?? '';
          final audioFile = exerciseData['audio_file']?.toString();
          if (name.isNotEmpty && audioFile != null) {
            audioMap[name.toLowerCase()] = audioFile;
          }
        }
      }
    } catch (e) {
      print('Error loading audio files from YAML: $e');
    }
    return audioMap;
  }

  static ExerciseModel _createBreakExercise(DateTime now) {
    return ExerciseModel(
      id: 'program_exercise_break_${now.millisecondsSinceEpoch}',
      name: 'Break',
      description: 'Rest period between exercises',
      category: 'flexibility',
      muscleGroup: 'full_body',
      equipment: 'none',
      difficulty: 'beginner',
      instructions: [
        'Take a moment to rest',
        'Breathe deeply',
        'Prepare for the next exercise',
      ],
      imageUrl: null,
      isCustom: false,
      createdAt: now,
      tags: ['rest', 'break'],
      measurementUnit: 'none',
      audioFile: 'audio/break_time.mp3',
    );
  }

  static Future<List<ExerciseModel>> _create7MinuteWorkoutExercises(
    DateTime now,
  ) async {
    final exercises = <ExerciseModel>[];

    // Get audio files from YAML
    final yamlAudioMap = await ProgramsService._getAudioFilesFromYaml();

    final exerciseData = [
      {
        'name': 'Jumping Jacks',
        'description': 'Full-body jumps, arms overhead',
        'category': 'cardio',
        'muscleGroup': 'full_body',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand with feet together and arms at sides',
          'Jump up, spreading legs shoulder-width apart',
          'Simultaneously raise arms overhead',
          'Jump back to starting position',
          'Repeat at a steady pace',
        ],
        'tags': ['cardio', 'full_body', 'warm_up'],
        'audioFile': 'audio/workouts/jumping_jacks.mp3',
      },
      {
        'name': 'Wall Sit',
        'description': 'Back against wall, knees at 90°',
        'category': 'strength',
        'muscleGroup': 'legs',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand with back flat against a wall',
          'Slide down until knees are at 90 degrees',
          'Keep back pressed against wall',
          'Hold position',
          'Keep core engaged',
        ],
        'tags': ['legs', 'isometric', 'strength'],
        'audioFile': 'audio/workouts/wall_sit.mp3',
      },
      {
        'name': 'Push-Ups',
        'description': 'Standard push-ups (knees optional)',
        'category': 'strength',
        'muscleGroup': 'chest',
        'equipment': 'bodyweight',
        'difficulty': 'beginner',
        'instructions': [
          'Start in plank position',
          'Lower body until chest nearly touches floor',
          'Push back up to starting position',
          'Keep core tight throughout',
          'Modify on knees if needed',
        ],
        'tags': ['chest', 'arms', 'core'],
        'audioFile': 'audio/workouts/Push-ups.mp3',
      },
      {
        'name': 'Abdominal Crunch',
        'description': 'Crunch up using core',
        'category': 'strength',
        'muscleGroup': 'core',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Lie on back with knees bent',
          'Place hands behind head',
          'Lift shoulders off ground',
          'Contract abs and crunch up',
          'Lower with control',
        ],
        'tags': ['core', 'abs', 'strength'],
        'audioFile': 'audio/workouts/abdominal_crunch.mp3',
      },
      {
        'name': 'Step-Ups',
        'description': 'Alternate stepping up and down',
        'category': 'strength',
        'muscleGroup': 'legs',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand facing a chair or bench',
          'Step up with one foot',
          'Bring other foot up',
          'Step down with first foot',
          'Alternate legs',
        ],
        'tags': ['legs', 'cardio', 'functional'],
        'audioFile': 'audio/workouts/step_ups.mp3',
      },
      {
        'name': 'Squats',
        'description': 'Bodyweight squats',
        'category': 'strength',
        'muscleGroup': 'legs',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand with feet shoulder-width apart',
          'Lower down as if sitting in a chair',
          'Keep knees behind toes',
          'Lower until thighs parallel to floor',
          'Push back up to standing',
        ],
        'tags': ['legs', 'full_body', 'strength'],
        'audioFile': 'audio/workouts/bodyweight_squats.mp3',
      },
      {
        'name': 'Triceps Dips',
        'description': 'Hands on chair, bend elbows',
        'category': 'strength',
        'muscleGroup': 'arms',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Sit on edge of chair',
          'Place hands on edge, fingers forward',
          'Slide forward off chair',
          'Lower body by bending elbows',
          'Push back up to starting position',
        ],
        'tags': ['arms', 'triceps', 'strength'],
        'audioFile': 'audio/workouts/triceps_dips.mp3',
      },
      {
        'name': 'Plank',
        'description': 'Forearms on floor, body straight',
        'category': 'strength',
        'muscleGroup': 'core',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Start in push-up position',
          'Lower to forearms',
          'Keep body in straight line',
          'Engage core and glutes',
          'Hold position',
        ],
        'tags': ['core', 'isometric', 'strength'],
        'audioFile': 'audio/workouts/Plank.mp3',
      },
      {
        'name': 'High Knees',
        'description': 'Fast knees up',
        'category': 'cardio',
        'muscleGroup': 'legs',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand tall with feet hip-width apart',
          'Run in place, bringing knees up high',
          'Pump arms naturally',
          'Maintain quick pace',
          'Land on balls of feet',
        ],
        'tags': ['cardio', 'legs', 'full_body'],
        'audioFile': null, // No audio file available
      },
      {
        'name': 'Lunges',
        'description': 'Alternating forward lunges',
        'category': 'strength',
        'muscleGroup': 'legs',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Stand with feet hip-width apart',
          'Step forward with one leg',
          'Lower until both knees at 90 degrees',
          'Push back to starting position',
          'Alternate legs',
        ],
        'tags': ['legs', 'strength', 'functional'],
        'audioFile': 'audio/workouts/lunges.mp3',
      },
      {
        'name': 'Push-Up + Rotation',
        'description': 'Push-up then rotate into side plank',
        'category': 'strength',
        'muscleGroup': 'core',
        'equipment': 'none',
        'difficulty': 'intermediate',
        'instructions': [
          'Perform a push-up',
          'At the top, rotate body to side plank',
          'Extend top arm toward ceiling',
          'Return to push-up position',
          'Alternate sides',
        ],
        'tags': ['core', 'chest', 'strength'],
        'audioFile': 'audio/workouts/push_up_rotation.mp3',
      },
      {
        'name': 'Side Plank',
        'description': 'Hold side plank (switch sides halfway)',
        'category': 'strength',
        'muscleGroup': 'core',
        'equipment': 'none',
        'difficulty': 'beginner',
        'instructions': [
          'Lie on side, propped on forearm',
          'Lift hips off ground',
          'Keep body in straight line',
          'Hold position',
          'Switch sides halfway through',
        ],
        'tags': ['core', 'isometric', 'strength'],
        'audioFile': 'audio/workouts/side_plank.mp3',
      },
    ];

    for (int i = 0; i < exerciseData.length; i++) {
      final data = exerciseData[i];
      final exerciseName = data['name'] as String;
      // Use audio file from YAML if available, otherwise use hardcoded value
      final audioFile =
          yamlAudioMap[exerciseName.toLowerCase()] ??
          (data['audioFile'] as String?);
      final exercise = ExerciseModel(
        id: 'program_exercise_${i + 1}_${now.millisecondsSinceEpoch}',
        name: exerciseName,
        description: data['description'] as String,
        category: data['category'] as String,
        muscleGroup: data['muscleGroup'] as String,
        equipment: data['equipment'] as String,
        difficulty: data['difficulty'] as String,
        instructions: List<String>.from(data['instructions'] as List),
        imageUrl: null, // Will be set from workout_icons
        isCustom: false,
        createdAt: now,
        tags: List<String>.from(data['tags'] as List),
        measurementUnit: 'none',
        audioFile: audioFile,
      );
      exercises.add(exercise);
    }

    return exercises;
  }

  static List<TimedWorkoutModel> _create7MinuteWorkoutPrograms(
    DateTime now,
    Map<String, ExerciseModel> exerciseMap,
    ExerciseModel breakExercise,
  ) {
    final programs = <TimedWorkoutModel>[];

    // Exercise sequence for 7-minute workout
    final workoutSequence = [
      {'name': 'Jumping Jacks', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Wall Sit', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Push-Ups', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Abdominal Crunch', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Step-Ups', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Squats', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Triceps Dips', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Plank', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'High Knees', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Lunges', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Push-Up + Rotation', 'time': 30},
      {'name': 'Break', 'time': 10},
      {'name': 'Side Plank', 'time': 30},
    ];

    // Create 2 programs with the same sequence
    for (int i = 0; i < 2; i++) {
      final workoutOrder = <TimedWorkoutItem>[];

      for (final item in workoutSequence) {
        final exerciseName = item['name'] as String;
        final time = item['time'] as int;

        ExerciseModel? exercise;
        if (exerciseName == 'Break') {
          exercise = breakExercise;
        } else {
          // Try multiple variations of the name for matching
          exercise =
              exerciseMap[exerciseName.toLowerCase()] ??
              exerciseMap[exerciseName] ??
              exerciseMap[exerciseName.toLowerCase().replaceAll(' ', '-')] ??
              exerciseMap[exerciseName
                  .toLowerCase()
                  .replaceAll('+', ' ')
                  .trim()];
        }

        if (exercise != null) {
          workoutOrder.add(
            TimedWorkoutItem(
              workoutId: exercise.id,
              time: time,
              useTimed: true,
            ),
          );
        }
      }

      final program = TimedWorkoutModel(
        id: 'program_7min_${i + 1}_${now.millisecondsSinceEpoch}',
        name: i == 0 ? '7 Minutes Workout' : '7 Minutes Workout 2',
        workoutOrder: workoutOrder,
        createdAt: now,
        isCustom: false,
        imageUrl: null, // Will use first exercise image
        isBookmarked: false,
        timesPerformed: 0,
        completionDates: [],
      );

      programs.add(program);
    }

    return programs;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/exercise_model.dart';

void main() {
  group('Audio File Sync Tests', () {
    setUp(() async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(ExerciseModelAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('ExerciseModel should store audioFile correctly', () {
      final exercise = ExerciseModel(
        id: 'test_exercise_1',
        name: 'Jumping Jacks',
        description: 'A cardio exercise',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'beginner',
        instructions: ['Jump', 'Land'],
        createdAt: DateTime.now(),
        audioFile: 'audio/workouts/jumping_jacks.mp3',
      );

      expect(exercise.audioFile, equals('audio/workouts/jumping_jacks.mp3'));
      expect(exercise.name, equals('Jumping Jacks'));
    });

    test('ExerciseModel audioFile should persist in Hive', () async {
      final box = await Hive.openBox<ExerciseModel>('testExercises');

      final exercise = ExerciseModel(
        id: 'test_exercise_1',
        name: 'Jumping Jacks',
        description: 'A cardio exercise',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'beginner',
        instructions: ['Jump', 'Land'],
        createdAt: DateTime.now(),
        audioFile: 'audio/workouts/jumping_jacks.mp3',
      );

      await box.put(exercise.id, exercise);
      final retrieved = box.get('test_exercise_1');

      expect(retrieved?.audioFile, equals('audio/workouts/jumping_jacks.mp3'));
      expect(retrieved?.name, equals('Jumping Jacks'));

      await box.close();
    });

    test('ExerciseModel audioFile can be updated and saved', () async {
      final box = await Hive.openBox<ExerciseModel>('testExercises2');

      // Create exercise without audioFile
      final exercise = ExerciseModel(
        id: 'test_exercise_2',
        name: 'Burpees',
        description: 'A full body exercise',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'intermediate',
        instructions: ['Squat', 'Jump back', 'Push up', 'Jump forward', 'Jump up'],
        createdAt: DateTime.now(),
        audioFile: null,
      );

      await box.put(exercise.id, exercise);

      // Verify audioFile is null initially
      var retrieved = box.get('test_exercise_2');
      expect(retrieved?.audioFile, isNull);

      // Update audioFile
      retrieved!.audioFile = 'audio/workouts/burpees.mp3';
      await retrieved.save();

      // Retrieve again and verify
      final updated = box.get('test_exercise_2');
      expect(updated?.audioFile, equals('audio/workouts/burpees.mp3'));

      await box.close();
    });

    test('Exercise name matching should be case-insensitive', () {
      // Simulate the name normalization logic used in sync
      String normalizeExerciseName(String name) {
        return name.toLowerCase().trim();
      }

      expect(normalizeExerciseName('Jumping Jacks'), equals('jumping jacks'));
      expect(normalizeExerciseName('JUMPING JACKS'), equals('jumping jacks'));
      expect(normalizeExerciseName('  Jumping Jacks  '), equals('jumping jacks'));
      expect(normalizeExerciseName('jumping jacks'), equals('jumping jacks'));
    });

    test('Audio map building from YAML data should work correctly', () {
      // Simulate YAML data structure
      final yamlExercises = [
        {'name': 'Jumping Jacks', 'audio_file': 'audio/workouts/jumping_jacks.mp3'},
        {'name': 'Burpees', 'audio_file': 'audio/workouts/burpees.mp3'},
        {'name': 'Push-Ups', 'audio_file': 'audio/workouts/push_ups.mp3'},
        {'name': 'No Audio Exercise', 'audio_file': null},
        {'name': 'Empty Audio Exercise', 'audio_file': ''},
      ];

      // Build audio map (same logic as in updateAudioFilesFromYaml)
      final audioMap = <String, String>{};
      for (final exerciseData in yamlExercises) {
        final name = exerciseData['name']?.toString() ?? '';
        final audioFile = exerciseData['audio_file']?.toString();
        if (name.isNotEmpty && audioFile != null && audioFile.isNotEmpty) {
          audioMap[name.toLowerCase().trim()] = audioFile;
        }
      }

      expect(audioMap.length, equals(3)); // Only 3 have valid audio files
      expect(audioMap['jumping jacks'], equals('audio/workouts/jumping_jacks.mp3'));
      expect(audioMap['burpees'], equals('audio/workouts/burpees.mp3'));
      expect(audioMap['push-ups'], equals('audio/workouts/push_ups.mp3'));
      expect(audioMap.containsKey('no audio exercise'), isFalse);
      expect(audioMap.containsKey('empty audio exercise'), isFalse);
    });

    test('Audio sync should only update exercises with different audioFile', () async {
      final box = await Hive.openBox<ExerciseModel>('testExercises3');

      // Create exercises
      final exercise1 = ExerciseModel(
        id: 'ex_1',
        name: 'Jumping Jacks',
        description: 'Test',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'beginner',
        instructions: [],
        createdAt: DateTime.now(),
        audioFile: null, // No audio file initially
      );

      final exercise2 = ExerciseModel(
        id: 'ex_2',
        name: 'Burpees',
        description: 'Test',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'intermediate',
        instructions: [],
        createdAt: DateTime.now(),
        audioFile: 'audio/workouts/burpees.mp3', // Already has correct audio
      );

      await box.put(exercise1.id, exercise1);
      await box.put(exercise2.id, exercise2);

      // Simulate YAML audio map
      final audioMap = {
        'jumping jacks': 'audio/workouts/jumping_jacks.mp3',
        'burpees': 'audio/workouts/burpees.mp3',
      };

      // Simulate sync logic
      int updatedCount = 0;
      for (final exercise in box.values) {
        final normalizedName = exercise.name.toLowerCase().trim();
        final yamlAudioFile = audioMap[normalizedName];

        if (yamlAudioFile != null && exercise.audioFile != yamlAudioFile) {
          exercise.audioFile = yamlAudioFile;
          await exercise.save();
          updatedCount++;
        }
      }

      // Only exercise1 should be updated (exercise2 already had the correct audioFile)
      expect(updatedCount, equals(1));

      // Verify the updates
      expect(box.get('ex_1')?.audioFile, equals('audio/workouts/jumping_jacks.mp3'));
      expect(box.get('ex_2')?.audioFile, equals('audio/workouts/burpees.mp3'));

      await box.close();
    });

    test('Multiple exercises with same lowercase name should all be found', () async {
      final box = await Hive.openBox<ExerciseModel>('testExercises4');

      // This simulates the case where ProgramsService creates "Jumping Jacks"
      // and DefaultWorkoutsService also creates "Jumping Jacks"
      final exercise1 = ExerciseModel(
        id: 'default_exercise_30',
        name: 'Jumping Jacks',
        description: 'From default workouts',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'bodyweight',
        difficulty: 'beginner',
        instructions: [],
        createdAt: DateTime.now(),
        audioFile: null,
      );

      final exercise2 = ExerciseModel(
        id: 'program_exercise_1_123456',
        name: 'Jumping Jacks',
        description: 'From programs',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'none',
        difficulty: 'beginner',
        instructions: [],
        createdAt: DateTime.now(),
        audioFile: null,
      );

      await box.put(exercise1.id, exercise1);
      await box.put(exercise2.id, exercise2);

      // Simulate YAML audio map
      final audioMap = {
        'jumping jacks': 'audio/workouts/jumping_jacks.mp3',
      };

      // Simulate sync logic - should update BOTH exercises
      int updatedCount = 0;
      for (final exercise in box.values) {
        final normalizedName = exercise.name.toLowerCase().trim();
        final yamlAudioFile = audioMap[normalizedName];

        if (yamlAudioFile != null && exercise.audioFile != yamlAudioFile) {
          exercise.audioFile = yamlAudioFile;
          await exercise.save();
          updatedCount++;
        }
      }

      expect(updatedCount, equals(2)); // Both should be updated
      expect(box.get('default_exercise_30')?.audioFile,
             equals('audio/workouts/jumping_jacks.mp3'));
      expect(box.get('program_exercise_1_123456')?.audioFile,
             equals('audio/workouts/jumping_jacks.mp3'));

      await box.close();
    });
  });
}

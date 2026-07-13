// lib/utils/workout_service.dart
import 'package:hive/hive.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';
import '../models/workout_set_model.dart';

/// Service for processing workout completion, evaluating records, and saving activity data
class WorkoutService {
  /// Process completed workout data:
  /// - Evaluates personal records (max weight, max reps, max volume)
  /// - Saves last workout reps and weights to exercises
  /// - Updates exercise usage statistics
  /// - Returns list of exercise IDs where new PRs were set
  static Future<List<String>> processWorkoutCompletion({
    required WorkoutSessionModel session,
    required Map<String, List<WorkoutSetModel>> exerciseSets,
    required List<ExerciseModel> exercises,
  }) async {
    final newPersonalRecords = <String>[];

    // Ensure exercises box is open
    if (!Hive.isBoxOpen('exercises')) {
      await Hive.openBox<ExerciseModel>('exercises');
    }
    final exercisesBox = Hive.box<ExerciseModel>('exercises');

    // Process each exercise
    for (final exercise in exercises) {
      final sets = exerciseSets[exercise.id];
      if (sets == null || sets.isEmpty) continue;

      // Save ALL sets (completed and uncompleted) for next workout
      // Extract reps and values from ALL sets
      final reps = sets.map((set) => set.reps).toList();
      final weights = sets
          .map((set) => set.value)
          .toList(); // value can be weight or duration

      // Update last workout data with ALL sets
      exercise.updateLastWorkoutData(reps, weights);

      // Filter only completed sets for PR evaluation and statistics
      final completedSets = sets.where((set) => set.isCompleted).toList();

      // Only increment usage and evaluate PRs if there are completed sets
      if (completedSets.isNotEmpty) {
        // Increment usage statistics
        exercise.incrementUsage();

        // Evaluate personal records (only based on completed sets)
        final hasNewPR = _evaluatePersonalRecords(
          exercise: exercise,
          completedSets: completedSets,
        );

        if (hasNewPR) {
          newPersonalRecords.add(exercise.id);
          // Mutate only — session is not in a box yet; caller persists via put().
          // addPersonalRecord() calls Hive save() and fails on first exit.
          if (!session.personalRecordsSet.contains(exercise.id)) {
            session.personalRecordsSet.add(exercise.id);
          }
        }
      }

      // Persist exercise updates (models may call save() only when already in-box)
      await exercisesBox.put(exercise.id, exercise);
    }

    return newPersonalRecords;
  }

  /// Evaluate personal records for an exercise based on completed sets
  /// Returns true if a new PR was set
  static bool _evaluatePersonalRecords({
    required ExerciseModel exercise,
    required List<WorkoutSetModel> completedSets,
  }) {
    bool hasNewPR = false;

    // Filter sets with value (for strength exercises with weight)
    final unit = exercise.measurementUnit;
    final weightedSets = completedSets
        .where(
          (set) =>
              (set.measurementType == 'kg' || set.measurementType == 'lbs') &&
              set.value != null &&
              set.value! > 0,
        )
        .toList();

    if (weightedSets.isNotEmpty) {
      // 1. Max Weight PR (single rep max or heaviest set)
      final maxWeight = weightedSets
          .map((set) => set.value!)
          .reduce((a, b) => a > b ? a : b);
      if (exercise.personalRecord == null ||
          maxWeight > exercise.personalRecord!) {
        exercise.updatePersonalRecord(maxWeight, unit);
        hasNewPR = true;
      }

      // 2. Max Reps PR (for same weight or bodyweight exercises)
      // Could track max reps separately if needed in the future

      // 3. Max Volume PR (total weight lifted: sum of weight * reps)
      // Could track total volume separately if needed in the future
      // For now, we'll use max weight as the primary PR
    } else {
      // For bodyweight exercises, track max reps
      final maxReps = completedSets
          .map((set) => set.reps)
          .reduce((a, b) => a > b ? a : b);
      // If exercise doesn't have a PR yet, set it based on reps
      if (exercise.personalRecord == null) {
        exercise.updatePersonalRecord(maxReps.toDouble(), 'reps');
        hasNewPR = true;
      } else if (maxReps > exercise.personalRecord!) {
        exercise.updatePersonalRecord(maxReps.toDouble(), 'reps');
        hasNewPR = true;
      }
    }

    return hasNewPR;
  }

  /// Sessions where this exercise had at least one completed set.
  static List<WorkoutSessionModel> sessionsForExercise(String exerciseId) {
    if (!Hive.isBoxOpen('workoutSessions')) return [];
    final sessions = Hive.box<WorkoutSessionModel>('workoutSessions').values
        .where((session) => sessionContainsExercise(session, exerciseId))
        .toList();
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  static bool sessionContainsExercise(
    WorkoutSessionModel session,
    String exerciseId,
  ) {
    if (session.completedExerciseIds.contains(exerciseId)) return true;
    if ((session.exerciseCompletedSets[exerciseId] ?? 0) > 0) return true;

    final sets = exerciseSetsFromSession(session, exerciseId);
    if (sets == null) return false;
    return sets.any((s) => s['isCompleted'] == true);
  }

  /// Raw set maps for an exercise from session.additionalData['exerciseSets'].
  static List<Map<String, dynamic>>? exerciseSetsFromSession(
    WorkoutSessionModel session,
    String exerciseId,
  ) {
    final raw = session.additionalData['exerciseSets'];
    if (raw is! Map) return null;
    final entry = raw[exerciseId];
    if (entry is! List) return null;

    return entry
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Stats for one exercise within a session (completed sets only).
  static ExerciseSessionStats? statsForExerciseInSession(
    WorkoutSessionModel session,
    String exerciseId, {
    String measurementUnit = 'kg',
  }) {
    final sets = exerciseSetsFromSession(session, exerciseId);
    if (sets == null || sets.isEmpty) {
      if (!session.completedExerciseIds.contains(exerciseId) &&
          (session.exerciseCompletedSets[exerciseId] ?? 0) <= 0) {
        return null;
      }
      return ExerciseSessionStats(
        completedSets: session.exerciseCompletedSets[exerciseId] ?? 0,
        totalReps: 0,
        averageWeight: null,
        maxReps: null,
        maxWeight: null,
        unit: measurementUnit,
      );
    }

    final completed = sets.where((s) => s['isCompleted'] == true).toList();
    if (completed.isEmpty) return null;

    final reps = completed
        .map((s) => (s['reps'] as num?)?.toInt() ?? 0)
        .toList();
    final weights = completed
        .map((s) => (s['value'] as num?)?.toDouble())
        .whereType<double>()
        .where((w) => w > 0)
        .toList();

    final showWeight =
        measurementUnit == 'kg' ||
        measurementUnit == 'lbs' ||
        completed.any((s) {
          final t = s['measurementType']?.toString();
          return t == 'kg' || t == 'lbs';
        });

    return ExerciseSessionStats(
      completedSets: completed.length,
      totalReps: reps.fold(0, (a, b) => a + b),
      averageWeight: showWeight && weights.isNotEmpty
          ? weights.reduce((a, b) => a + b) / weights.length
          : null,
      maxReps: reps.isEmpty ? null : reps.reduce((a, b) => a > b ? a : b),
      maxWeight: showWeight && weights.isNotEmpty
          ? weights.reduce((a, b) => a > b ? a : b)
          : null,
      unit: measurementUnit,
    );
  }

  /// Get last workout data for an exercise (for pre-filling next workout)
  static WorkoutData? getLastWorkoutData(ExerciseModel exercise) {
    if (exercise.lastWorkoutReps == null ||
        exercise.lastWorkoutWeights == null ||
        exercise.lastWorkoutReps!.isEmpty) {
      return null;
    }

    return WorkoutData(
      reps: List<int>.from(exercise.lastWorkoutReps!),
      weights: List<double?>.from(exercise.lastWorkoutWeights!),
      date: exercise.lastWorkoutDate,
    );
  }

  /// Create default sets based on last workout data
  static List<WorkoutSetModel> createSetsFromLastWorkout({
    required ExerciseModel exercise,
    required String exerciseId,
  }) {
    final lastWorkout = getLastWorkoutData(exercise);

    if (lastWorkout == null) {
      // Return default sets if no last workout data
      final unit = exercise.measurementUnit;
      double? defaultValue;

      if (unit == 'seconds') {
        defaultValue = 30.0;
      } else if (unit == 'none') {
        defaultValue = null;
      } else {
        defaultValue = 10.0;
      }

      return [
        WorkoutSetModel(
          id: '${exerciseId}_set_1',
          exerciseId: exerciseId,
          reps: 10,
          measurementType: unit,
          value: defaultValue,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
        WorkoutSetModel(
          id: '${exerciseId}_set_2',
          exerciseId: exerciseId,
          reps: 10,
          measurementType: unit,
          value: defaultValue,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
        WorkoutSetModel(
          id: '${exerciseId}_set_3',
          exerciseId: exerciseId,
          reps: 10,
          measurementType: unit,
          value: defaultValue,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
      ];
    }

    // Create sets based on last workout
    return List.generate(
      lastWorkout.reps.length,
      (index) => WorkoutSetModel(
        id: '${exerciseId}_set_${index + 1}',
        exerciseId: exerciseId,
        reps: lastWorkout.reps[index],
        measurementType: exercise.measurementUnit,
        value: lastWorkout.weights[index],
        restTimeSeconds: 60,
        isCompleted: false,
      ),
    );
  }
}

/// Data class for last workout information
class WorkoutData {
  final List<int> reps;
  final List<double?> weights;
  final DateTime? date;

  WorkoutData({required this.reps, required this.weights, this.date});
}

/// Aggregated stats for one exercise inside a saved session.
class ExerciseSessionStats {
  final int completedSets;
  final int totalReps;
  final double? averageWeight;
  final int? maxReps;
  final double? maxWeight;
  final String unit;

  ExerciseSessionStats({
    required this.completedSets,
    required this.totalReps,
    required this.averageWeight,
    required this.maxReps,
    required this.maxWeight,
    required this.unit,
  });

  String get averageWeightLabel {
    if (averageWeight == null) return '—';
    final v = averageWeight!;
    final rounded = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return '$rounded $unit';
  }

  String get maxWeightLabel {
    if (maxWeight == null) return '—';
    final v = maxWeight!;
    final rounded = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return '$rounded $unit';
  }
}

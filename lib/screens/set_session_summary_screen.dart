// lib/screens/set_session_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/models/workout_set_model.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';
import 'package:solo_level_system/screens/workout_summary_screen.dart';
import 'package:solo_level_system/utils/workout_service.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';

class SetSessionSummaryScreen extends StatelessWidget {
  final WorkoutSetCategoryModel setCategory;
  final String setLabel;
  final List<ExerciseModel> exercises;
  final int initialExerciseIndex;

  const SetSessionSummaryScreen({
    super.key,
    required this.setCategory,
    required this.setLabel,
    required this.exercises,
    this.initialExerciseIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final planRows = exercises.map(_planForExercise).toList();
    final totalSets = planRows.fold<int>(0, (sum, row) => sum + row.setCount);
    final estMinLow = (totalSets * 2.5).round().clamp(5, 999);
    final estMinHigh = (totalSets * 4.0).round().clamp(estMinLow + 5, 999);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColorPalette.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'SET $setLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  setCategory.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${exercises.length} exercises · ~$totalSets sets',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  'Est. $estMinLow–$estMinHigh min',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 28),
                Text(
                  "Today's plan",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColorPalette.grey800,
                  ),
                ),
                const SizedBox(height: 12),
                ...planRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return _PlanExerciseTile(
                    index: index + 1,
                    exercise: row.exercise,
                    volumeLabel: row.volumeLabel,
                    muscleLabel: row.muscleLabel,
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryActionButton(
                    text: 'Begin Workout',
                    icon: Icons.play_arrow,
                    onPressed: () => _beginWorkout(context),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _beginWorkout(BuildContext context) async {
    final session = WorkoutSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineId: setCategory.id,
      routineName: setCategory.name,
      startTime: DateTime.now(),
      durationMinutes: 0,
      completedExerciseIds: [],
      exerciseCompletedSets: {},
      isCompleted: false,
      status: 'active',
      totalSetsCompleted: 0,
      totalRepsCompleted: 0,
      caloriesBurned: 0,
      additionalData: {'setCategoryId': setCategory.id, 'setLabel': setLabel},
    );

    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutSessionScreen(
          session: session,
          exercises: exercises,
          sequentialMode: true,
          initialExerciseIndex: initialExerciseIndex,
        ),
      ),
    );

    if (!context.mounted) return;

    if (result is Map<String, dynamic> && result['paused'] == true) {
      Navigator.pop(context, {
        'paused': true,
        'session': session,
        'exercises': exercises,
        'exerciseIndex': result['exerciseIndex'] as int? ?? 0,
        'setCategoryId': setCategory.id,
      });
      return;
    }

    if (result is Map<String, dynamic> && result['session'] != null) {
      try {
        setCategory.lastPerformanceDate = DateTime.now();
        setCategory.modifiedAt = DateTime.now();
        await setCategory.save();
      } catch (_) {
        // Category may already be closed; ignore
      }

      if (!context.mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutSummaryScreen(
            session: result['session'] as WorkoutSessionModel,
            exercises: result['exercises'] as List<ExerciseModel>,
            totalSetsCompleted: result['totalSetsCompleted'] as int,
            totalSets: result['totalSets'] as int,
          ),
        ),
      );
      return;
    }

    // Discarded or cancelled — return to Sets
    Navigator.pop(context);
  }

  static _ExercisePlanRow _planForExercise(ExerciseModel exercise) {
    final sets = _plannedSets(exercise);
    final unit = exercise.measurementUnit;
    final setCount = sets.length;

    String? valuePart;
    final values = sets
        .map((s) => s.value)
        .whereType<double>()
        .where((v) => v > 0)
        .toList();

    if (values.isNotEmpty) {
      final avg = values.reduce((a, b) => a + b) / values.length;
      switch (unit) {
        case 'seconds':
          final minutes = (avg / 60).floor();
          final seconds = (avg % 60).round();
          valuePart = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
          break;
        case 'none':
          valuePart = null;
          break;
        case 'lbs':
          valuePart = '${avg.toStringAsFixed(0)} lbs';
          break;
        case 'kg':
        default:
          valuePart = '${avg.toStringAsFixed(0)} kg';
          break;
      }
    }

    final volumeLabel = valuePart == null
        ? '$setCount sets'
        : '$setCount sets · $valuePart';

    final muscleLabel = exercise.muscleGroup.replaceAll('_', ' ');

    return _ExercisePlanRow(
      exercise: exercise,
      setCount: setCount,
      volumeLabel: volumeLabel,
      muscleLabel: muscleLabel,
    );
  }

  static List<WorkoutSetModel> _plannedSets(ExerciseModel exercise) {
    if (!Hive.isBoxOpen('exercises')) {
      return WorkoutService.createSetsFromLastWorkout(
        exercise: exercise,
        exerciseId: exercise.id,
      );
    }
    final box = Hive.box<ExerciseModel>('exercises');
    final refreshed = box.get(exercise.id) ?? exercise;
    return WorkoutService.createSetsFromLastWorkout(
      exercise: refreshed,
      exerciseId: exercise.id,
    );
  }
}

class _ExercisePlanRow {
  final ExerciseModel exercise;
  final int setCount;
  final String volumeLabel;
  final String muscleLabel;

  const _ExercisePlanRow({
    required this.exercise,
    required this.setCount,
    required this.volumeLabel,
    required this.muscleLabel,
  });
}

class _PlanExerciseTile extends StatelessWidget {
  final int index;
  final ExerciseModel exercise;
  final String volumeLabel;
  final String muscleLabel;

  const _PlanExerciseTile({
    required this.index,
    required this.exercise,
    required this.volumeLabel,
    required this.muscleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '$index.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColorPalette.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WorkoutIconWidget(
                imageUrl: exercise.imageUrl,
                size: 44,
                backgroundColor: AppColorPalette.grey100,
                placeholder: Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$volumeLabel · $muscleLabel',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

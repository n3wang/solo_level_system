// lib/screens/workout_routines_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/screens/add_edit_routine_screen.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class WorkoutRoutinesScreen extends StatefulWidget {
  final Function(WorkoutSessionModel?)? onActiveSessionChanged;
  final WorkoutSessionModel? activeSession;

  const WorkoutRoutinesScreen({
    super.key,
    this.onActiveSessionChanged,
    this.activeSession,
  });

  @override
  _WorkoutRoutinesScreenState createState() => _WorkoutRoutinesScreenState();
}

class _WorkoutRoutinesScreenState extends State<WorkoutRoutinesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<WorkoutRoutineModel>('workoutRoutines');
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _ensureBoxIsOpen<T>(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<T>(boxName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (widget.activeSession != null)
            IconButton(
              icon: Icon(Icons.stop, color: Colors.red[300]),
              onPressed: _endWorkoutSession,
              tooltip: 'End Current Session',
            ),
        ],
      ),
      body: _isLoading
          ? LoadingIndicator(message: 'Loading routines...')
          : _buildRoutinesList(),
      floatingActionButton: CustomFloatingActionButton(
        heroTag: "workout_routines_new_routine",
        label: 'New Routine',
        icon: Icons.add,
        onPressed: _createNewRoutine,
      ),
    );
  }

  Widget _buildRoutinesList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutRoutineModel>(
        'workoutRoutines',
      ).listenable(),
      builder: (context, Box<WorkoutRoutineModel> box, _) {
        final routines = box.values.toList();

        if (routines.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center,
            title: 'No Workout Routines',
            subtitle:
                'Create your first routine to get started with structured workouts',
            action: PrimaryActionButton(
              text: 'Create Routine',
              icon: Icons.add,
              onPressed: _createNewRoutine,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: routines.length,
          itemBuilder: (context, index) {
            final routine = routines[index];
            return _buildRoutineCard(routine);
          },
        );
      },
    );
  }

  Widget _buildRoutineCard(WorkoutRoutineModel routine) {
    return BaseCard(
      onTap: () => _startRoutine(routine),
      onLongPress: () => _showRoutineOptions(routine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: routine.name,
            description: routine.description,
            color: _getRoutineColor(routine),
            icon: Icons.fitness_center,
            trailing: _buildRoutineTrailing(routine),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                label: 'Exercises',
                value: '${routine.exerciseIds.length}',
                icon: Icons.list,
              ),
              SizedBox(width: 8),
              StatChip(
                label: 'Category',
                value: routine.category.replaceAll('_', ' '),
                icon: Icons.category,
              ),
              SizedBox(width: 8),
              StatChip(
                label: 'Difficulty',
                value: routine.difficulty,
                icon: Icons.signal_cellular_alt,
                color: _getDifficultyColor(routine.difficulty),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineTrailing(WorkoutRoutineModel routine) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (routine.estimatedDurationMinutes > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${routine.estimatedDurationMinutes}min',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SizedBox(width: 8),
        Icon(Icons.play_arrow, color: Theme.of(context).primaryColor),
      ],
    );
  }

  Color _getRoutineColor(WorkoutRoutineModel routine) {
    switch (routine.category) {
      case 'strength':
        return Colors.red;
      case 'cardio':
        return Colors.orange;
      case 'flexibility':
        return Colors.green;
      case 'sports':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _startRoutine(WorkoutRoutineModel routine) async {
    try {
      // Close the bottom sheet if it's open
      Navigator.pop(context);
    } catch (e) {
      // Bottom sheet not open, continue
    }

    try {
      // Load exercises for the routine
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
      final exercises = routine.exerciseIds
          .map(
            (id) => exercisesBox.values.firstWhere(
              (ex) => ex.id == id,
              orElse: () => ExerciseModel(
                id: id,
                name: 'Unknown Exercise',
                description: '',
                category: 'strength',
                muscleGroup: 'other',
                equipment: 'bodyweight',
                difficulty: 'beginner',
                instructions: [],
                isCustom: false,
                createdAt: DateTime.now(),
                tags: [],
                isArchived: false,
              ),
            ),
          )
          .toList();

      // Create workout session
      final session = WorkoutSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        routineId: routine.id,
        routineName: routine.name,
        startTime: DateTime.now(),
        durationMinutes: 0,
        completedExerciseIds: [],
        exerciseCompletedSets: {},
        isCompleted: false,
        status: 'active',
        totalSetsCompleted: 0,
        totalRepsCompleted: 0,
        caloriesBurned: 0,
      );

      // Update active session
      widget.onActiveSessionChanged?.call(session);

      // Navigate to active workout session screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveWorkoutSessionScreen(
            session: session,
            exercises: exercises,
            routine: routine,
          ),
        ),
      );

      // Clear active session when returning
      widget.onActiveSessionChanged?.call(null);

      // Show summary modal if workout was completed
      if (result != null && result is Map<String, dynamic>) {
        _showWorkoutSummaryModal(
          result['session'] as WorkoutSessionModel,
          result['exercises'] as List<ExerciseModel>,
          result['totalSetsCompleted'] as int,
          result['totalSets'] as int,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting routine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRoutineOptions(WorkoutRoutineModel routine) {
    showModalBottomSheet(
      context: context,
      builder: (context) => OptionsBottomSheet(
        options: [
          BottomSheetOption(
            title: 'Start Workout',
            icon: Icons.play_arrow,
            onTap: () => _startRoutine(routine),
          ),
          BottomSheetOption(
            title: 'Edit Routine',
            icon: Icons.edit,
            onTap: () => _editRoutine(routine),
          ),
          BottomSheetOption(
            title: 'Duplicate Routine',
            icon: Icons.copy,
            onTap: () => _duplicateRoutine(routine),
          ),
          BottomSheetOption(
            title: 'Delete Routine',
            icon: Icons.delete,
            onTap: () => _deleteRoutine(routine),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _createNewRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditRoutineScreen()),
    );
  }

  void _editRoutine(WorkoutRoutineModel routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoutineScreen(routine: routine),
      ),
    );
  }

  void _duplicateRoutine(WorkoutRoutineModel routine) {
    // TODO: Implement routine duplication logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicating routine: ${routine.name}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteRoutine(WorkoutRoutineModel routine) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Routine',
        message:
            'Are you sure you want to delete "${routine.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          routine.delete();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Routine deleted')));
        },
      ),
    );
  }

  void _endWorkoutSession() {
    if (widget.activeSession != null) {
      // TODO: Implement end session logic
      widget.onActiveSessionChanged?.call(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout session ended'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showWorkoutSummaryModal(
    WorkoutSessionModel session,
    List<ExerciseModel> exercises,
    int totalSetsCompleted,
    int totalSets,
  ) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: session.isCompleted ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      session.isCompleted
                          ? 'Workout Complete!'
                          : 'Workout Saved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (session.isCompleted) ...[
                        Icon(Icons.celebration, size: 80, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'Great Job!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You completed your workout',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.save, size: 80, color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'Workout Saved',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your progress has been saved',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      SizedBox(height: 40),
                      _buildSummaryStatCard(
                        'Routine',
                        session.routineName.isEmpty
                            ? 'Custom Workout'
                            : session.routineName,
                        Icons.fitness_center,
                        Colors.purple,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryStatCard(
                              'Duration',
                              _formatSummaryDuration(duration),
                              Icons.timer,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryStatCard(
                              'Exercises',
                              '${session.completedExerciseIds.length}/${exercises.length}',
                              Icons.list,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryStatCard(
                              'Sets',
                              '$totalSetsCompleted/$totalSets',
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryStatCard(
                              'Reps',
                              '${session.totalRepsCompleted}',
                              Icons.repeat,
                              Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      if (session.totalWeightLifted != null &&
                          session.totalWeightLifted! > 0) ...[
                        SizedBox(height: 16),
                        _buildSummaryStatCard(
                          'Total Weight',
                          '${session.totalWeightLifted!.toStringAsFixed(0)} kg',
                          Icons.fitness_center,
                          Colors.red,
                        ),
                      ],
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSummaryDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

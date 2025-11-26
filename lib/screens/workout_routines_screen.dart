// lib/screens/workout_routines_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/screens/add_edit_routine_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class WorkoutRoutinesScreen extends StatefulWidget {
  final Function(WorkoutSessionModel?)? onActiveSessionChanged;
  final WorkoutSessionModel? activeSession;

  const WorkoutRoutinesScreen({
    Key? key,
    this.onActiveSessionChanged,
    this.activeSession,
  }) : super(key: key);

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
        label: 'New Routine',
        icon: Icons.add,
        onPressed: _createNewRoutine,
      ),
    );
  }

  Widget _buildRoutinesList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutRoutineModel>('workoutRoutines').listenable(),
      builder: (context, Box<WorkoutRoutineModel> box, _) {
        final routines = box.values.toList();

        if (routines.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center,
            title: 'No Workout Routines',
            subtitle: 'Create your first routine to get started with structured workouts',
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
              color: Colors.blue.withOpacity(0.1),
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

  void _startRoutine(WorkoutRoutineModel routine) {
    // TODO: Implement routine start logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting routine: ${routine.name}'),
        duration: Duration(seconds: 2),
      ),
    );
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
      MaterialPageRoute(
        builder: (context) => AddEditRoutineScreen(),
      ),
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
        message: 'Are you sure you want to delete "${routine.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          routine.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Routine deleted')),
          );
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
}
// lib/screens/exercise_details_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final ExerciseModel exercise;

  const ExerciseDetailsScreen({super.key, required this.exercise});

  @override
  _ExerciseDetailsScreenState createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  late Box<WorkoutSessionModel> _sessionsBox;
  List<WorkoutSessionModel> _exerciseHistory = [];

  @override
  void initState() {
    super.initState();
    _loadExerciseHistory();
  }

  void _loadExerciseHistory() async {
    _sessionsBox = await Hive.openBox<WorkoutSessionModel>('workoutSessions');
    final allSessions = _sessionsBox.values.toList();

    setState(() {
      _exerciseHistory =
          allSessions
              .where(
                (session) =>
                    session.completedExerciseIds.contains(widget.exercise.id),
              )
              .toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        actions: [
          IconButton(icon: Icon(Icons.edit), onPressed: _editExercise),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExerciseHeader(),
            SizedBox(height: 24),
            _buildPersonalRecords(),
            SizedBox(height: 24),
            _buildInstructions(),
            SizedBox(height: 24),
            _buildExerciseHistory(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "exercise_details_quick_start",
        onPressed: _startQuickWorkout,
        icon: Icon(Icons.play_arrow),
        label: Text('Quick Start'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildExerciseHeader() {
    return Card(
      color: Colors.white, // White background
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getMuscleGroupColor(widget.exercise.muscleGroup),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: WorkoutIconWidget(
                      imageUrl: widget.exercise.imageUrl,
                      size: 80,
                      placeholder: Icon(
                        _getMuscleGroupIcon(widget.exercise.muscleGroup),
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exercise.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.exercise.muscleGroup.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.exercise.difficulty.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.exercise.description.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                widget.exercise.description,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  widget.exercise.category.toUpperCase(),
                  Icons.category,
                  Colors.blue,
                ),
                _buildInfoChip(
                  widget.exercise.equipment == 'bodyweight'
                      ? 'BODYWEIGHT'
                      : widget.exercise.equipment.toUpperCase(),
                  Icons.fitness_center,
                  Colors.purple,
                ),
                if (widget.exercise.tags.isNotEmpty)
                  ...widget.exercise.tags.map(
                    (tag) => _buildInfoChip(
                      tag.toUpperCase(),
                      Icons.tag,
                      Colors.green,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecords() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRecordCard(
                    'Best Weight',
                    widget.exercise.personalRecord?.toString() ?? '-',
                    widget.exercise.personalRecordUnit ?? 'kg',
                    Icons.fitness_center,
                    Colors.red,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildRecordCard(
                    'Times Used',
                    _exerciseHistory.length.toString(),
                    'sessions',
                    Icons.history,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildRecordCard(
                    'Last Used',
                    _exerciseHistory.isNotEmpty
                        ? _formatDate(_exerciseHistory.first.startTime)
                        : 'Never',
                    '',
                    Icons.access_time,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty) ...[
                SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 10, color: color)),
              ],
            ],
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (widget.exercise.instructions.isEmpty)
              Text(
                'No instructions provided.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...widget.exercise.instructions.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseHistory() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Recent History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_exerciseHistory.isEmpty)
              Text(
                'No workout history for this exercise.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...(_exerciseHistory
                  .take(5)
                  .map((session) => _buildHistoryItem(session))),
            if (_exerciseHistory.length > 5)
              TextButton(
                onPressed: _viewFullHistory,
                child: Text('View All History'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(WorkoutSessionModel session) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            session.isCompleted ? Icons.check_circle : Icons.cancel,
            color: session.isCompleted ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.routineName,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDate(session.startTime),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${session.durationMinutes} min',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMuscleGroupColor(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'back':
        return Colors.blue;
      case 'legs':
        return Colors.green;
      case 'arms':
        return Colors.orange;
      case 'shoulders':
        return Colors.purple;
      case 'core':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Icons.favorite;
      case 'back':
        return Icons.view_agenda;
      case 'legs':
        return Icons.directions_run;
      case 'arms':
        return Icons.fitness_center;
      case 'shoulders':
        return Icons.accessibility;
      case 'core':
        return Icons.center_focus_strong;
      default:
        return Icons.fitness_center;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _editExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExerciseScreen(exercise: widget.exercise),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {
          // Refresh the screen
        });
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        _duplicateExercise();
        break;
      case 'delete':
        _deleteExercise();
        break;
    }
  }

  void _duplicateExercise() async {
    final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
    final newExercise = ExerciseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${widget.exercise.name} (Copy)',
      description: widget.exercise.description,
      category: widget.exercise.category,
      muscleGroup: widget.exercise.muscleGroup,
      equipment: widget.exercise.equipment,
      difficulty: widget.exercise.difficulty,
      instructions: List.from(widget.exercise.instructions),
      isCustom: true,
      createdAt: DateTime.now(),
      tags: List.from(widget.exercise.tags),
      isArchived: false,
    );

    await exercisesBox.add(newExercise);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exercise duplicated successfully')));
  }

  void _deleteExercise() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Exercise'),
        content: Text(
          'Are you sure you want to delete "${widget.exercise.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.exercise.delete();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Exercise deleted')));
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startQuickWorkout() {
    // Create a quick workout session with just this exercise
    final session = WorkoutSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineId: 'quick_${widget.exercise.id}',
      routineName: 'Quick: ${widget.exercise.name}',
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutSessionScreen(
          session: session,
          exercises: [widget.exercise],
        ),
      ),
    );
  }

  void _viewFullHistory() {
    // Navigate to a full history screen
    // This would be implemented as a separate screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Full history view not implemented yet')),
    );
  }
}

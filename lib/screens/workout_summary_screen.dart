// lib/screens/workout_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final WorkoutSessionModel session;
  final List<ExerciseModel> exercises;
  final int totalSetsCompleted;
  final int totalSets;

  const WorkoutSummaryScreen({
    Key? key,
    required this.session,
    required this.exercises,
    required this.totalSetsCompleted,
    required this.totalSets,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;

    return Scaffold(
      backgroundColor: session.isCompleted ? Colors.green.shade50 : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: session.isCompleted ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        title: Text(session.isCompleted ? 'Workout Complete!' : 'Workout Saved'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => _navigateToHome(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            if (session.isCompleted) ...[
              Icon(
                Icons.celebration,
                size: 80,
                color: Colors.green,
              ),
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
              Icon(
                Icons.save,
                size: 80,
                color: Colors.blue,
              ),
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
            _buildStatCard(
              'Routine',
              session.routineName.isEmpty ? 'Custom Workout' : session.routineName,
              Icons.fitness_center,
              Colors.purple,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Duration',
                    _formatDuration(duration),
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
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
                  child: _buildStatCard(
                    'Sets',
                    '$totalSetsCompleted/$totalSets',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Reps',
                    '${session.totalRepsCompleted}',
                    Icons.repeat,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            if (session.totalWeightLifted != null && session.totalWeightLifted! > 0) ...[
              SizedBox(height: 16),
              _buildStatCard(
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
                onPressed: () => _navigateToHome(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _navigateToHome(BuildContext context) {
    // Pop all the way to the root (MainNavigationScreen)
    // This ensures we get back to the main screen with bottom navigation
    // User will see the workout tab and can use bottom nav to switch tabs
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

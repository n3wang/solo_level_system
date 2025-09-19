// lib/screens/active_workout_session_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_model.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';

class ActiveWorkoutSessionScreen extends StatefulWidget {
  final WorkoutSessionModel session;
  final List<ExerciseModel> exercises;
  final WorkoutRoutineModel? routine;

  const ActiveWorkoutSessionScreen({
    Key? key,
    required this.session,
    required this.exercises,
    this.routine,
  }) : super(key: key);

  @override
  _ActiveWorkoutSessionScreenState createState() =>
      _ActiveWorkoutSessionScreenState();
}

class _ActiveWorkoutSessionScreenState extends State<ActiveWorkoutSessionScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  Duration _workoutDuration = Duration.zero;
  int _currentExerciseIndex = 0;
  bool _isPaused = false;
  bool _isResting = false;
  Timer? _restTimer;
  Duration _restDuration = Duration.zero;

  late TabController _tabController;
  Map<String, List<WorkoutSetModel>> _exerciseSets = {};
  Map<String, int> _completedSets = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.exercises.length,
      vsync: this,
    );
    _initializeWorkout();
    _startTimer();
  }

  void _initializeWorkout() {
    // Initialize sets for each exercise
    for (final exercise in widget.exercises) {
      if (widget.routine != null &&
          widget.routine!.exerciseSets.containsKey(exercise.id)) {
        // Use routine's predefined sets
        _exerciseSets[exercise.id] = List.from(
          widget.routine!.exerciseSets[exercise.id]!,
        );
      } else {
        // Create default sets
        _exerciseSets[exercise.id] = [
          WorkoutSetModel(
            id: '${exercise.id}_set_1',
            exerciseId: exercise.id,
            reps: 10,
            weight: 0,
            restTimeSeconds: 60,
            isCompleted: false,
          ),
          WorkoutSetModel(
            id: '${exercise.id}_set_2',
            exerciseId: exercise.id,
            reps: 10,
            weight: 0,
            restTimeSeconds: 60,
            isCompleted: false,
          ),
          WorkoutSetModel(
            id: '${exercise.id}_set_3',
            exerciseId: exercise.id,
            reps: 10,
            weight: 0,
            restTimeSeconds: 60,
            isCompleted: false,
          ),
        ];
      }
      _completedSets[exercise.id] = 0;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _workoutDuration = _workoutDuration + Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _restTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.session.routineName),
              Text(
                _formatDuration(_workoutDuration),
                style: TextStyle(fontSize: 14, color: Colors.grey[300]),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: _showEndWorkoutDialog,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: widget.exercises.map((exercise) {
              final completedSets = _completedSets[exercise.id] ?? 0;
              final totalSets = _exerciseSets[exercise.id]?.length ?? 0;

              return Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$completedSets/$totalSets',
                      style: TextStyle(
                        fontSize: 10,
                        color: completedSets == totalSets ? Colors.green : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        body: Column(
          children: [
            if (_isResting) _buildRestTimer(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.exercises.map((exercise) {
                  return _buildExerciseView(exercise);
                }).toList(),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildRestTimer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      color: Colors.blue.withOpacity(0.1),
      child: Column(
        children: [
          Text(
            'Rest Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Text(
            _formatDuration(_restDuration),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _adjustRestTime(-10),
                child: Text('-10s'),
              ),
              TextButton(
                onPressed: () => _adjustRestTime(-30),
                child: Text('-30s'),
              ),
              TextButton(onPressed: _skipRest, child: Text('Skip')),
              TextButton(
                onPressed: () => _adjustRestTime(30),
                child: Text('+30s'),
              ),
              TextButton(
                onPressed: () => _adjustRestTime(60),
                child: Text('+60s'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseView(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id] ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExerciseHeader(exercise),
          SizedBox(height: 24),
          _buildExerciseInstructions(exercise),
          SizedBox(height: 24),
          _buildSetsTable(exercise, sets),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader(ExerciseModel exercise) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getMuscleGroupColor(exercise.muscleGroup),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getMuscleGroupIcon(exercise.muscleGroup),
                color: Colors.white,
                size: 30,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.equipment}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  if (exercise.personalRecord != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'PR: ${exercise.personalRecord}kg',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInstructions(ExerciseModel exercise) {
    if (exercise.instructions.isEmpty) return SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.info_outline, color: Colors.blue),
        title: Text('Instructions'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: exercise.instructions
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsTable(ExerciseModel exercise, List<WorkoutSetModel> sets) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Table(
              columnWidths: {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: [
                    _buildTableHeader('Set'),
                    _buildTableHeader('Reps'),
                    _buildTableHeader('Weight (kg)'),
                    _buildTableHeader('✓'),
                  ],
                ),
                ...sets.asMap().entries.map(
                  (entry) => _buildSetRow(exercise, entry.key, entry.value),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addSet(exercise),
                    icon: Icon(Icons.add),
                    label: Text('Add Set'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _allSetsCompleted(exercise)
                        ? () => _nextExercise()
                        : null,
                    icon: Icon(Icons.arrow_forward),
                    label: Text('Next Exercise'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allSetsCompleted(exercise)
                          ? Colors.green
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildSetRow(
    ExerciseModel exercise,
    int index,
    WorkoutSetModel set,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '${index + 1}',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(4),
          child: TextFormField(
            initialValue: set.reps.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              set.reps = int.tryParse(value) ?? 0;
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(4),
          child: TextFormField(
            initialValue: set.weight?.toString() ?? '0',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              set.weight = double.tryParse(value) ?? 0;
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Checkbox(
            value: set.isCompleted,
            onChanged: (value) => _toggleSetCompletion(exercise, index),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Workout Time',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  _formatDuration(_workoutDuration),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          VerticalDivider(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sets Completed',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${_getTotalCompletedSets()}/${_getTotalSets()}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          VerticalDivider(),
          ElevatedButton(
            onPressed: _showEndWorkoutDialog,
            child: Text('Finish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleSetCompletion(ExerciseModel exercise, int setIndex) {
    setState(() {
      final sets = _exerciseSets[exercise.id]!;
      final set = sets[setIndex];
      set.isCompleted = !set.isCompleted;

      if (set.isCompleted) {
        set.completedAt = DateTime.now();
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 0) + 1;
        _startRestTimer(set.restTimeSeconds);
      } else {
        set.completedAt = null;
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 1) - 1;
      }
    });
  }

  void _startRestTimer(int restSeconds) {
    if (_isResting) return;

    setState(() {
      _isResting = true;
      _restDuration = Duration(seconds: restSeconds);
    });

    _restTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_restDuration.inSeconds > 0) {
          _restDuration = _restDuration - Duration(seconds: 1);
        } else {
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restDuration = _restDuration + Duration(seconds: seconds);
      if (_restDuration.inSeconds <= 0) {
        _skipRest();
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restDuration = Duration.zero;
    });
  }

  void _addSet(ExerciseModel exercise) {
    setState(() {
      final sets = _exerciseSets[exercise.id]!;
      sets.add(
        WorkoutSetModel(
          id: '${exercise.id}_set_${sets.length + 1}',
          exerciseId: exercise.id,
          reps: sets.isNotEmpty ? sets.last.reps : 10,
          weight: sets.isNotEmpty ? sets.last.weight : 0,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
      );
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < widget.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
      _tabController.animateTo(_currentExerciseIndex);
    } else {
      _showEndWorkoutDialog();
    }
  }

  bool _allSetsCompleted(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id] ?? [];
    return sets.isNotEmpty && sets.every((set) => set.isCompleted);
  }

  int _getTotalCompletedSets() {
    return _completedSets.values.fold(0, (sum, count) => sum + count);
  }

  int _getTotalSets() {
    return _exerciseSets.values.fold(0, (sum, sets) => sum + sets.length);
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

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('End Workout?'),
            content: Text(
              'Are you sure you want to end this workout? Your progress will be saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Continue'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  _endWorkout(false);
                },
                child: Text('End Workout'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEndWorkoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Workout'),
        content: Text('How would you like to end this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endWorkout(false);
            },
            child: Text('Save & Exit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endWorkout(true);
            },
            child: Text('Mark Complete'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _endWorkout(bool markComplete) async {
    setState(() => _isLoading = true);

    try {
      // Update session
      widget.session.endTime = DateTime.now();
      widget.session.durationMinutes = _workoutDuration.inMinutes;
      widget.session.isCompleted = markComplete;
      widget.session.status = markComplete ? 'completed' : 'cancelled';
      widget.session.totalSetsCompleted = _getTotalCompletedSets();
      widget.session.completedExerciseIds = widget.exercises
          .where((ex) => _allSetsCompleted(ex))
          .map((ex) => ex.id)
          .toList();

      // Save session
      final sessionsBox = await Hive.openBox<WorkoutSessionModel>(
        'workoutSessions',
      );
      await sessionsBox.add(widget.session);

      // Update routine completion count if applicable
      if (markComplete && widget.routine != null) {
        final routinesBox = await Hive.openBox<WorkoutRoutineModel>(
          'workoutRoutines',
        );
        final routineIndex = routinesBox.values.toList().indexWhere(
          (r) => r.id == widget.routine!.id,
        );
        if (routineIndex != -1) {
          final routine = routinesBox.getAt(routineIndex)!;
          routine.timesCompleted += 1;
          routine.lastCompletedAt = DateTime.now();
          await routinesBox.putAt(routineIndex, routine);
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            markComplete ? 'Workout completed successfully!' : 'Workout saved',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving workout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// lib/screens/workout_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/screens/exercise_details_screen.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/add_edit_routine_screen.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';

class WorkoutModeScreen extends StatefulWidget {
  const WorkoutModeScreen({super.key});

  @override
  _WorkoutModeScreenState createState() => _WorkoutModeScreenState();
}

class _WorkoutModeScreenState extends State<WorkoutModeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  WorkoutSessionModel? _activeSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_activeSession != null)
            IconButton(
              icon: Icon(Icons.stop, color: Colors.red),
              onPressed: _endWorkoutSession,
            ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreateOptions(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.list), text: 'Routines'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
            Tab(icon: Icon(Icons.play_circle), text: 'Quick Start'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoutinesTab(),
          _buildExercisesTab(),
          _buildQuickStartTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _activeSession != null
          ? FloatingActionButton(
              heroTag: "workout_mode_active_session",
              onPressed: () => _navigateToActiveWorkout(),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              child: Icon(Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildRoutinesTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<WorkoutRoutineModel>('workoutRoutines'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading routines: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<WorkoutRoutineModel>(
            'workoutRoutines',
          ).listenable(),
          builder: (context, Box<WorkoutRoutineModel> box, _) {
            final routines = box.values.toList();

            if (routines.isEmpty) {
              return _buildEmptyState(
                'No Workout Routines',
                'Create your first routine to get started',
                Icons.fitness_center,
                () => _createNewRoutine(),
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
      },
    );
  }

  Widget _buildRoutineCard(WorkoutRoutineModel routine) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _startRoutine(routine),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (routine.description.isNotEmpty)
                          Text(
                            routine.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
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
                    onSelected: (value) => _handleRoutineAction(value, routine),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    '${routine.exerciseIds.length} exercises',
                    Icons.list,
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    '${routine.estimatedDurationMinutes} min',
                    Icons.timer,
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    '${routine.timesCompleted} completed',
                    Icons.check_circle,
                  ),
                ],
              ),
              if (routine.tags.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: routine.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag, style: TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExercisesTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<ExerciseModel>('exercises'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading exercises: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
          builder: (context, Box<ExerciseModel> box, _) {
            final exercises = box.values.toList();

            if (exercises.isEmpty) {
              return _buildEmptyState(
                'No Exercises',
                'Add exercises to build your workout library',
                Icons.add_circle,
                () => _createNewExercise(),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _buildExerciseCard(exercise);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewExerciseDetails(exercise),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          exercise.muscleGroup,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (index) => Icon(
                                index < _getDifficultyLevel(exercise.difficulty)
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.orange,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              exercise.equipment == 'bodyweight'
                                  ? 'Bodyweight'
                                  : exercise.equipment,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_circle_filled, size: 32),
                    onPressed: () => _quickStartExercise(exercise),
                  ),
                ],
              ),
              if (exercise.personalRecord != null &&
                  exercise.personalRecord! > 0) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'PR: ${exercise.formattedPersonalRecord}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeSession != null) _buildActiveSessionCard(),
          _buildQuickStartOptions(),
          SizedBox(height: 24),
          _buildRecentWorkouts(),
          SizedBox(height: 24),
          _buildWorkoutTemplates(),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.play_circle, color: Colors.green, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workout in Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        _activeSession?.routineName ?? 'Custom Workout',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _navigateToActiveWorkout,
                  child: Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildQuickStartCard(
              'Empty Workout',
              'Start a blank workout',
              Icons.add_circle,
              Colors.blue,
              () => _startEmptyWorkout(),
            ),
            _buildQuickStartCard(
              'Last Workout',
              'Repeat your last session',
              Icons.replay,
              Colors.orange,
              () => _repeatLastWorkout(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStartCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentWorkouts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Workouts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        // Placeholder for recent workouts
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Recent workouts will appear here'),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Templates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        // Placeholder for workout templates
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Workout templates will appear here'),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading workout history: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<WorkoutSessionModel>(
            'workoutSessions',
          ).listenable(),
          builder: (context, Box<WorkoutSessionModel> box, _) {
            final sessions = box.values.toList()
              ..sort((a, b) => b.startTime.compareTo(a.startTime));

            if (sessions.isEmpty) {
              return _buildEmptyState(
                'No Workout History',
                'Your completed workouts will appear here',
                Icons.history,
                () => _tabController.animateTo(2), // Navigate to Quick Start
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildHistoryCard(session);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(WorkoutSessionModel session) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewSessionDetails(session),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.routineName.isEmpty
                              ? 'Custom Workout'
                              : session.routineName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDate(session.startTime),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.endTime != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    '${session.completedExerciseIds.length} exercises',
                    Icons.fitness_center,
                  ),
                  SizedBox(width: 8),
                  if (session.endTime != null)
                    _buildInfoChip(
                      '${session.endTime!.difference(session.startTime).inMinutes} min',
                      Icons.timer,
                    ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    '${session.totalWeightLifted?.toStringAsFixed(0) ?? '0'}kg',
                    Icons.fitness_center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(Icons.add),
              label: Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Action methods
  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.fitness_center, color: Colors.blue),
              title: Text('Create Exercise'),
              subtitle: Text('Add a new exercise to your library'),
              onTap: () {
                Navigator.pop(context);
                _createNewExercise();
              },
            ),
            ListTile(
              leading: Icon(Icons.list, color: Colors.green),
              title: Text('Create Routine'),
              subtitle: Text('Build a new workout routine'),
              onTap: () {
                Navigator.pop(context);
                _createNewRoutine();
              },
            ),
            ListTile(
              leading: Icon(Icons.flash_on, color: Colors.orange),
              title: Text('Quick Add Exercise'),
              subtitle: Text('Rapidly add a simple exercise'),
              onTap: () {
                Navigator.pop(context);
                _showQuickAddExercise();
              },
            ),
            ListTile(
              leading: Icon(Icons.play_circle_filled, color: Colors.red),
              title: Text('Start Empty Workout'),
              subtitle: Text('Begin a workout without a routine'),
              onTap: () {
                Navigator.pop(context);
                _startEmptyWorkout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createNewExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditExerciseScreen()),
    ).then((result) {
      if (result == true) {
        // Refresh exercises list
        setState(() {});
      }
    });
  }

  void _createNewRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditRoutineScreen()),
    ).then((result) {
      if (result == true) {
        // Refresh routines list
        setState(() {});
      }
    });
  }

  void _startRoutine(WorkoutRoutineModel routine) async {
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

      setState(() {
        _activeSession = session;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveWorkoutSessionScreen(
            session: session,
            exercises: exercises,
            routine: routine,
          ),
        ),
      ).then((_) {
        setState(() {
          _activeSession = null;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting routine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startEmptyWorkout() {
    // Create an empty workout session that user can add exercises to on the fly
    final session = WorkoutSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineId: 'empty_workout',
      routineName: 'Empty Workout',
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

    setState(() {
      _activeSession = session;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutSessionScreen(
          session: session,
          exercises: [], // Start with no exercises
        ),
      ),
    ).then((_) {
      setState(() {
        _activeSession = null;
      });
    });
  }

  void _showQuickAddExercise() {
    final nameController = TextEditingController();
    String selectedMuscleGroup = 'chest';
    String selectedEquipment = 'bodyweight';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Quick Add Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Exercise Name',
                    hintText: 'e.g., Push-ups, Squats',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMuscleGroup,
                  decoration: InputDecoration(
                    labelText: 'Muscle Group',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'chest',
                            'back',
                            'legs',
                            'arms',
                            'shoulders',
                            'core',
                            'glutes',
                            'calves',
                            'forearms',
                            'traps',
                            'lats',
                            'quads',
                            'hamstrings',
                            'biceps',
                            'triceps',
                            'delts',
                            'full_body',
                            'other',
                          ]
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(
                                group[0].toUpperCase() + group.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedMuscleGroup = value!;
                    });
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedEquipment,
                  decoration: InputDecoration(
                    labelText: 'Equipment',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'bodyweight',
                            'dumbbells',
                            'barbell',
                            'machine',
                            'cables',
                            'resistance_bands',
                            'kettlebell',
                            'other',
                          ]
                          .map(
                            (equipment) => DropdownMenuItem(
                              value: equipment,
                              child: Text(
                                equipment[0].toUpperCase() +
                                    equipment.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedEquipment = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _quickCreateExercise(
                    nameController.text.trim(),
                    selectedMuscleGroup,
                    selectedEquipment,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickCreateExercise(
    String name,
    String muscleGroup,
    String equipment,
  ) async {
    try {
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');

      final exercise = ExerciseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: '',
        category: 'strength',
        muscleGroup: muscleGroup,
        equipment: equipment,
        difficulty: 'beginner',
        instructions: [],
        isCustom: true,
        createdAt: DateTime.now(),
        tags: [],
        isArchived: false,
      );

      await exercisesBox.add(exercise);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise "$name" added successfully')),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating exercise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _repeatLastWorkout() {
    // Repeat the last completed workout
    print('Repeat last workout');
  }

  void _quickStartExercise(ExerciseModel exercise) {
    // Create a quick workout session with just this exercise
    final session = WorkoutSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineId: 'quick_${exercise.id}',
      routineName: 'Quick: ${exercise.name}',
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

    setState(() {
      _activeSession = session;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ActiveWorkoutSessionScreen(session: session, exercises: [exercise]),
      ),
    ).then((_) {
      setState(() {
        _activeSession = null;
      });
    });
  }

  void _viewExerciseDetails(ExerciseModel exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailsScreen(exercise: exercise),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh if exercise was updated
        setState(() {});
      }
    });
  }

  void _viewSessionDetails(WorkoutSessionModel session) {
    // Navigate to session details screen
    print('View session details');
  }

  void _navigateToActiveWorkout() {
    if (_activeSession != null) {
      // Navigate to active workout screen with current session
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Resuming active workout...')));
    }
  }

  void _endWorkoutSession() {
    // End the current workout session
    setState(() {
      _activeSession = null;
    });
  }

  void _handleRoutineAction(String action, WorkoutRoutineModel routine) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditRoutineScreen(routine: routine),
          ),
        ).then((result) {
          if (result == true) {
            setState(() {});
          }
        });
        break;
      case 'duplicate':
        _duplicateRoutine(routine);
        break;
      case 'delete':
        _deleteRoutine(routine);
        break;
    }
  }

  void _duplicateRoutine(WorkoutRoutineModel routine) async {
    try {
      final routinesBox = await Hive.openBox<WorkoutRoutineModel>(
        'workoutRoutines',
      );
      final newRoutine = WorkoutRoutineModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${routine.name} (Copy)',
        description: routine.description,
        exerciseIds: List.from(routine.exerciseIds),
        exerciseSets: Map.from(routine.exerciseSets),
        category: routine.category,
        difficulty: routine.difficulty,
        estimatedDurationMinutes: routine.estimatedDurationMinutes,
        tags: List.from(routine.tags),
        isTemplate: true,
        isFavorite: false,
        createdAt: DateTime.now(),
        timesCompleted: 0,
        isArchived: false,
        notes: routine.notes,
        targetMuscleGroups: List.from(routine.targetMuscleGroups),
        createdBy: 'user',
      );

      await routinesBox.add(newRoutine);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Routine duplicated successfully')),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error duplicating routine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteRoutine(WorkoutRoutineModel routine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await routine.delete();
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Routine deleted')));
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting routine: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _getDifficultyLevel(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 1;
      case 'intermediate':
        return 3;
      case 'advanced':
        return 5;
      default:
        return 1;
    }
  }

  Color _getMuscleGroupColor(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'back':
        return Colors.blue;
      case 'shoulders':
        return Colors.orange;
      case 'arms':
        return Colors.purple;
      case 'legs':
        return Colors.green;
      case 'core':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Icons.fitness_center;
      case 'back':
        return Icons.fitness_center;
      case 'shoulders':
        return Icons.fitness_center;
      case 'arms':
        return Icons.fitness_center;
      case 'legs':
        return Icons.directions_run;
      case 'core':
        return Icons.fitness_center;
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

  // Helper method to ensure Hive boxes are opened
  Future<void> _ensureBoxIsOpen<T>(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<T>(boxName);
      }
    } catch (e) {
      print('Error opening box $boxName: $e');
      rethrow;
    }
  }
}

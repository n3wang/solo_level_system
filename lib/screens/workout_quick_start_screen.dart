// lib/screens/workout_quick_start_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class WorkoutQuickStartScreen extends StatefulWidget {
  final Function(WorkoutSessionModel?)? onActiveSessionChanged;

  const WorkoutQuickStartScreen({super.key, this.onActiveSessionChanged});

  @override
  _WorkoutQuickStartScreenState createState() =>
      _WorkoutQuickStartScreenState();
}

class _WorkoutQuickStartScreenState extends State<WorkoutQuickStartScreen> {
  bool _isLoading = true;
  String _selectedWorkoutType = 'custom';
  final List<ExerciseModel> _selectedExercises = [];
  int _estimatedDuration = 30;

  final List<QuickStartTemplate> _templates = [
    QuickStartTemplate(
      id: 'full_body',
      name: 'Full Body Strength',
      description:
          'Complete full body workout targeting all major muscle groups',
      duration: 45,
      difficulty: 'intermediate',
      icon: Icons.fitness_center,
      color: Colors.red,
    ),
    QuickStartTemplate(
      id: 'cardio_hiit',
      name: 'HIIT Cardio',
      description:
          'High-intensity interval training for cardiovascular fitness',
      duration: 20,
      difficulty: 'advanced',
      icon: Icons.directions_run,
      color: Colors.orange,
    ),
    QuickStartTemplate(
      id: 'upper_body',
      name: 'Upper Body Focus',
      description: 'Targeted workout for chest, back, shoulders, and arms',
      duration: 35,
      difficulty: 'intermediate',
      icon: Icons.accessibility_new,
      color: Colors.blue,
    ),
    QuickStartTemplate(
      id: 'flexibility',
      name: 'Flexibility & Mobility',
      description:
          'Stretching and mobility routine for recovery and flexibility',
      duration: 25,
      difficulty: 'beginner',
      icon: Icons.self_improvement,
      color: Colors.green,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<ExerciseModel>('exercises');
    await _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions');
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
      ),
      body: _isLoading
          ? LoadingIndicator(message: 'Loading workout options...')
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkoutTypeSelector(),
                  SizedBox(height: 24),
                  if (_selectedWorkoutType == 'template')
                    _buildTemplateSelector()
                  else
                    _buildCustomWorkoutBuilder(),
                  SizedBox(height: 24),
                  _buildStartWorkoutSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkoutTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildWorkoutTypeCard(
                'template',
                'Pre-made Templates',
                'Ready-to-use workout routines',
                Icons.library_books,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildWorkoutTypeCard(
                'custom',
                'Custom Workout',
                'Build your own workout',
                Icons.build,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutTypeCard(
    String type,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedWorkoutType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWorkoutType = type;
          _selectedExercises.clear();
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha:0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColorPalette.textSecondary, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppColorPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Template',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ...(_templates
            .map((template) => _buildTemplateCard(template))
            .toList()),
      ],
    );
  }

  Widget _buildTemplateCard(QuickStartTemplate template) {
    return BaseCard(
      margin: EdgeInsets.only(bottom: 12),
      onTap: () => _selectTemplate(template),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: template.color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(template.icon, color: template.color, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  template.description,
                  style: TextStyle(color: AppColorPalette.textSecondary, fontSize: 14),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    StatChip(
                      label: 'Duration',
                      value: '${template.duration}min',
                      icon: Icons.timer,
                    ),
                    SizedBox(width: 8),
                    StatChip(
                      label: 'Level',
                      value: template.difficulty,
                      icon: Icons.signal_cellular_alt,
                      color: _getDifficultyColor(template.difficulty),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: AppColorPalette.textSecondary),
        ],
      ),
    );
  }

  Widget _buildCustomWorkoutBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build Custom Workout',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        _buildDurationSelector(),
        SizedBox(height: 16),
        _buildExerciseSelector(),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated Duration: $_estimatedDuration minutes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Slider(
          value: _estimatedDuration.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          label: '$_estimatedDuration min',
          onChanged: (value) {
            setState(() {
              _estimatedDuration = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildExerciseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected Exercises (${_selectedExercises.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SecondaryActionButton(
              text: 'Add Exercise',
              icon: Icons.add,
              onPressed: _showExercisePicker,
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_selectedExercises.isEmpty)
          EmptyState(
            icon: Icons.fitness_center,
            title: 'No Exercises Selected',
            subtitle: 'Add exercises to build your custom workout',
            action: PrimaryActionButton(
              text: 'Add Exercise',
              icon: Icons.add,
              onPressed: _showExercisePicker,
            ),
          )
        else
          ..._selectedExercises.map(
            (exercise) => _buildSelectedExerciseCard(exercise),
          ),
      ],
    );
  }

  Widget _buildSelectedExerciseCard(ExerciseModel exercise) {
    return BaseCard(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.fitness_center, color: Theme.of(context).primaryColor),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  exercise.muscleGroup.replaceAll('_', ' '),
                  style: TextStyle(color: AppColorPalette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedExercises.remove(exercise);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStartWorkoutSection() {
    final canStart =
        _selectedWorkoutType == 'template' || _selectedExercises.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryActionButton(
          text: 'Start Workout',
          icon: Icons.play_arrow,
          onPressed: canStart ? _startWorkout : null,
        ),
        if (!canStart) ...[
          SizedBox(height: 8),
          Text(
            'Select a template or add exercises to start your workout',
            style: TextStyle(color: AppColorPalette.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
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

  void _selectTemplate(QuickStartTemplate template) {
    // TODO: Implement template selection logic
    setState(() {
      _estimatedDuration = template.duration;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected template: ${template.name}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showExercisePicker() {
    // TODO: Implement exercise picker dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exercise picker coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startWorkout() {
    // TODO: Implement workout start logic
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting workout session: $sessionId'),
        duration: Duration(seconds: 2),
      ),
    );

    // Simulate creating a workout session
    // widget.onActiveSessionChanged?.call(mockSession);
  }
}

class QuickStartTemplate {
  final String id;
  final String name;
  final String description;
  final int duration;
  final String difficulty;
  final IconData icon;
  final Color color;

  const QuickStartTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.icon,
    required this.color,
  });
}

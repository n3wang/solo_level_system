// lib/screens/workout_exercises_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/exercise_details_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class WorkoutExercisesScreen extends StatefulWidget {
  @override
  _WorkoutExercisesScreenState createState() => _WorkoutExercisesScreenState();
}

class _WorkoutExercisesScreenState extends State<WorkoutExercisesScreen> {
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedMuscleGroup = 'all';
  String _searchQuery = '';

  final List<String> _categories = [
    'all', 'strength', 'cardio', 'flexibility', 'sports', 'functional',
    'powerlifting', 'bodybuilding', 'crossfit', 'yoga', 'pilates'
  ];

  final List<String> _muscleGroups = [
    'all', 'chest', 'back', 'legs', 'arms', 'shoulders', 'core',
    'glutes', 'calves', 'full_body'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<ExerciseModel>('exercises');
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
          ? LoadingIndicator(message: 'Loading exercises...')
          : Column(
              children: [
                _buildSearchAndFilters(),
                Expanded(child: _buildExercisesList()),
              ],
            ),
      floatingActionButton: CustomFloatingActionButton(
        label: 'New Exercise',
        icon: Icons.add,
        onPressed: _createNewExercise,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          CustomTextField(
            controller: TextEditingController(text: _searchQuery),
            labelText: 'Search exercises',
            hintText: 'Enter exercise name...',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Expanded(
                child: CustomDropdownField<String>(
                  value: _selectedCategory,
                  labelText: 'Category',
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_formatCategoryName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'all';
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: CustomDropdownField<String>(
                  value: _selectedMuscleGroup,
                  labelText: 'Muscle Group',
                  items: _muscleGroups.map((muscle) {
                    return DropdownMenuItem(
                      value: muscle,
                      child: Text(_formatMuscleGroupName(muscle)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMuscleGroup = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
      builder: (context, Box<ExerciseModel> box, _) {
        final allExercises = box.values.toList();
        final filteredExercises = _filterExercises(allExercises);

        if (allExercises.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center,
            title: 'No Exercises',
            subtitle: 'Create your first exercise to build your workout library',
            action: PrimaryActionButton(
              text: 'Create Exercise',
              icon: Icons.add,
              onPressed: _createNewExercise,
            ),
          );
        }

        if (filteredExercises.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No Results Found',
            subtitle: 'Try adjusting your search or filter criteria',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredExercises.length,
          itemBuilder: (context, index) {
            final exercise = filteredExercises[index];
            return _buildExerciseCard(exercise);
          },
        );
      },
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise) {
    return BaseCard(
      onTap: () => _viewExerciseDetails(exercise),
      onLongPress: () => _showExerciseOptions(exercise),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: exercise.name,
            description: exercise.description,
            color: _getCategoryColor(exercise.category),
            icon: _getCategoryIcon(exercise.category),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                label: 'Category',
                value: _formatCategoryName(exercise.category),
                icon: Icons.category,
                color: _getCategoryColor(exercise.category),
              ),
              SizedBox(width: 8),
              StatChip(
                label: 'Muscle',
                value: _formatMuscleGroupName(exercise.muscleGroup),
                icon: Icons.accessibility_new,
              ),
              SizedBox(width: 8),
              StatChip(
                label: 'Level',
                value: _formatDifficultyName(exercise.difficulty),
                icon: Icons.signal_cellular_alt,
                color: _getDifficultyColor(exercise.difficulty),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ExerciseModel> _filterExercises(List<ExerciseModel> exercises) {
    return exercises.where((exercise) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!exercise.name.toLowerCase().contains(query) &&
            !exercise.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'all' && exercise.category != _selectedCategory) {
        return false;
      }

      // Muscle group filter
      if (_selectedMuscleGroup != 'all' &&
          exercise.muscleGroup != _selectedMuscleGroup) {
        return false;
      }

      return true;
    }).toList();
  }

  String _formatCategoryName(String category) {
    if (category == 'all') return 'All Categories';
    return category.replaceAll('_', ' ').split(' ').map((word) =>
        word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _formatMuscleGroupName(String muscle) {
    if (muscle == 'all') return 'All Muscles';
    return muscle.replaceAll('_', ' ').split(' ').map((word) =>
        word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _formatDifficultyName(String difficulty) {
    return difficulty[0].toUpperCase() + difficulty.substring(1);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'strength':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'flexibility':
        return Icons.self_improvement;
      case 'sports':
        return Icons.sports;
      default:
        return Icons.accessibility;
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

  void _viewExerciseDetails(ExerciseModel exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailsScreen(exercise: exercise),
      ),
    );
  }

  void _showExerciseOptions(ExerciseModel exercise) {
    showModalBottomSheet(
      context: context,
      builder: (context) => OptionsBottomSheet(
        options: [
          BottomSheetOption(
            title: 'View Details',
            icon: Icons.info,
            onTap: () => _viewExerciseDetails(exercise),
          ),
          BottomSheetOption(
            title: 'Edit Exercise',
            icon: Icons.edit,
            onTap: () => _editExercise(exercise),
          ),
          BottomSheetOption(
            title: 'Duplicate Exercise',
            icon: Icons.copy,
            onTap: () => _duplicateExercise(exercise),
          ),
          BottomSheetOption(
            title: 'Delete Exercise',
            icon: Icons.delete,
            onTap: () => _deleteExercise(exercise),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _createNewExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExerciseScreen(),
      ),
    );
  }

  void _editExercise(ExerciseModel exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExerciseScreen(exercise: exercise),
      ),
    );
  }

  void _duplicateExercise(ExerciseModel exercise) {
    // TODO: Implement exercise duplication logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicating exercise: ${exercise.name}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteExercise(ExerciseModel exercise) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Exercise',
        message: 'Are you sure you want to delete "${exercise.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          exercise.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exercise deleted')),
          );
        },
      ),
    );
  }
}
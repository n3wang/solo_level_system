// lib/screens/workout_exercises_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/utils/unlock_service.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/exercise_details_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';

class WorkoutExercisesScreen extends StatefulWidget {
  final String? filterSetId;
  final WorkoutSetCategoryModel? setCategory;

  const WorkoutExercisesScreen({super.key, this.filterSetId, this.setCategory});

  @override
  _WorkoutExercisesScreenState createState() => _WorkoutExercisesScreenState();
}

class _WorkoutExercisesScreenState extends State<WorkoutExercisesScreen> {
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedMuscleGroup = 'all';
  String _searchQuery = '';

  final List<String> _categories = [
    'all',
    'strength',
    'cardio',
    'flexibility',
    'sports',
    'functional',
    'powerlifting',
    'bodybuilding',
    'crossfit',
    'yoga',
    'pilates',
  ];

  final List<String> _muscleGroups = [
    'all',
    'chest',
    'back',
    'legs',
    'arms',
    'shoulders',
    'core',
    'glutes',
    'calves',
    'full_body',
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
    final isFiltered = widget.filterSetId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFiltered ? widget.setCategory!.name : 'Exercises'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? LoadingIndicator(message: 'Loading exercises...')
          : Column(
              children: [
                if (isFiltered) _buildSetFilterBanner(),
                _buildSearchAndFilters(),
                Expanded(child: _buildExercisesList()),
              ],
            ),
      floatingActionButton: CustomFloatingActionButton(
        heroTag: "workout_exercises_new_exercise",
        label: 'New Exercise',
        icon: Icons.add,
        onPressed: _createNewExercise,
      ),
    );
  }

  Widget _buildSetFilterBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 1))),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: _getSetColor(), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing exercises in ${widget.setCategory!.name}',
              style: TextStyle(
                color: _getSetColor(),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              // Show dialog to add/remove exercises from this set
              _manageSetExercises();
            },
            icon: Icon(Icons.settings, size: 18),
            label: Text('Manage'),
            style: TextButton.styleFrom(
              foregroundColor: _getSetColor(),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSetColor() {
    final set = widget.setCategory;
    if (set == null) return AppColorPalette.color1;
    return AppColorPalette.colorForSetPosition(set.position);
  }

  void _manageSetExercises() {
    final exercisesBox = Hive.box<ExerciseModel>('exercises');
    final setExerciseIds = widget.setCategory!.exerciseIds.toSet();
    // Hide locked (un-acquired) exercises, but keep any already in this set.
    final allExercises = exercisesBox.values
        .where((e) =>
            setExerciseIds.contains(e.id) ||
            UnlockService.isUnlocked('exercise:${e.name}'))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Manage Exercises in ${widget.setCategory!.name}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = allExercises[index];
                    final isInSet = setExerciseIds.contains(exercise.id);

                    return CheckboxListTile(
                      title: Text(exercise.name),
                      subtitle: Text(exercise.description),
                      value: isInSet,
                      onChanged: (bool? value) {
                        if (value == true) {
                          widget.setCategory!.addExercise(exercise.id);
                        } else {
                          widget.setCategory!.removeExercise(exercise.id);
                        }
                        // Force rebuild
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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
            subtitle:
                'Create your first exercise to build your workout library',
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
            customIcon: WorkoutIconWidget(
              imageUrl: exercise.imageUrl,
              size: 40,
              placeholder: Icon(
                _getCategoryIcon(exercise.category),
                color: _getCategoryColor(exercise.category),
                size: 20,
              ),
            ),
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
      // Card-unlock filter: hide exercises not acquired through the cards system.
      if (!UnlockService.isUnlocked('exercise:${exercise.name}')) {
        return false;
      }

      // Set filter - only show exercises in the selected set
      if (widget.filterSetId != null && widget.setCategory != null) {
        if (!widget.setCategory!.exerciseIds.contains(exercise.id)) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!exercise.name.toLowerCase().contains(query) &&
            !exercise.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'all' &&
          exercise.category != _selectedCategory) {
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
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  String _formatMuscleGroupName(String muscle) {
    if (muscle == 'all') return 'All Muscles';
    return muscle
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
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
    ExerciseDetailsScreen.show(context, exercise);
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
    AddEditExerciseScreen.showAsModal(context);
  }

  void _editExercise(ExerciseModel exercise) {
    AddEditExerciseScreen.showAsModal(context, exercise: exercise);
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
        message:
            'Are you sure you want to delete "${exercise.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          exercise.delete();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Exercise deleted')));
        },
      ),
    );
  }
}

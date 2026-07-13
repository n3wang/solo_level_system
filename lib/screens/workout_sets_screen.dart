// lib/screens/workout_sets_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/screens/add_edit_workout_set_screen.dart';
import 'package:solo_level_system/screens/workout_exercises_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class WorkoutSetsScreen extends StatefulWidget {
  final Function(WorkoutSessionModel?)? onActiveSessionChanged;
  final WorkoutSessionModel? activeSession;

  const WorkoutSetsScreen({
    super.key,
    this.onActiveSessionChanged,
    this.activeSession,
  });

  @override
  _WorkoutSetsScreenState createState() => _WorkoutSetsScreenState();
}

class _WorkoutSetsScreenState extends State<WorkoutSetsScreen> {
  bool _isLoading = true;
  static const int MAX_SETS = 5;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<WorkoutSetCategoryModel>('workoutSetCategories');
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
        title: Text('Workout Sets'),
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
          ? LoadingIndicator(message: 'Loading workout sets...')
          : _buildSetsList(),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: _canAddMoreSets()
          ? CustomFloatingActionButton(
              heroTag: "workout_sets_new_set",
              label: 'New Set',
              icon: Icons.add,
              onPressed: _createNewSet,
            )
          : null,
    );
  }

  bool _canAddMoreSets() {
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    return box.values.where((set) => set.isActive).length < MAX_SETS;
  }

  Widget _buildSetsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      ).listenable(),
      builder: (context, Box<WorkoutSetCategoryModel> box, _) {
        final allSets = box.values.toList();
        final activeSets = allSets.where((set) => set.isActive).toList();

        // Sort by position
        activeSets.sort((a, b) => a.position.compareTo(b.position));

        if (activeSets.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center,
            title: 'No Workout Sets',
            subtitle:
                'Create workout sets to organize your exercises (max $MAX_SETS sets)',
            action: PrimaryActionButton(
              text: 'Create First Set',
              icon: Icons.add,
              onPressed: _createNewSet,
            ),
          );
        }

        return Column(
          children: [
            if (activeSets.length < MAX_SETS)
              Padding(
                padding: EdgeInsets.all(16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You can create up to ${MAX_SETS - activeSets.length} more set${MAX_SETS - activeSets.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: activeSets.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorderSets(activeSets, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final setCategory = activeSets[index];
                  return _buildSetCard(
                    setCategory,
                    index,
                    key: ValueKey(setCategory.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSetCard(
    WorkoutSetCategoryModel setCategory,
    int index, {
    required Key key,
  }) {
    final exercisesBox = Hive.box<ExerciseModel>('exercises');
    final exerciseCount = setCategory.exerciseIds.length;
    final exercises = setCategory.exerciseIds
        .map((id) {
          try {
            return exercisesBox.values.firstWhere((ex) => ex.id == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<ExerciseModel>()
        .toList();

    return BaseCard(
      key: key,
      onTap: () => _viewSetExercises(setCategory),
      onLongPress: () => _showSetOptions(setCategory),
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getSetColor(setCategory).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getSetColor(setCategory),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: CardHeader(
                  title: setCategory.name,
                  description: setCategory.description.isEmpty
                      ? 'Tap to add exercises'
                      : setCategory.description,
                  color: _getSetColor(setCategory),
                  icon: Icons.fitness_center,
                ),
              ),
              Icon(Icons.drag_handle, color: Colors.grey),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                label: 'Exercises',
                value: '$exerciseCount',
                icon: Icons.list,
                color: _getSetColor(setCategory),
              ),
              SizedBox(width: 8),
              if (exercises.isNotEmpty) ...[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: exercises.take(3).map((exercise) {
                        return Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Chip(
                            label: Text(
                              exercise.name,
                              style: TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (exercises.length > 3)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '+${exercises.length - 3} more',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getSetColor(WorkoutSetCategoryModel setCategory) {
    return AppColorPalette.colorForSetPosition(setCategory.position);
  }

  void _reorderSets(
    List<WorkoutSetCategoryModel> sets,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final set = sets.removeAt(oldIndex);
    sets.insert(newIndex, set);

    // Update positions
    for (int i = 0; i < sets.length; i++) {
      sets[i].updatePosition(i);
    }
  }

  void _viewSetExercises(WorkoutSetCategoryModel setCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutExercisesScreen(
          filterSetId: setCategory.id,
          setCategory: setCategory,
        ),
      ),
    );
  }

  void _showSetOptions(WorkoutSetCategoryModel setCategory) {
    showModalBottomSheet(
      context: context,
      builder: (context) => OptionsBottomSheet(
        options: [
          BottomSheetOption(
            title: 'View Exercises',
            icon: Icons.fitness_center,
            onTap: () {
              Navigator.pop(context);
              _viewSetExercises(setCategory);
            },
          ),
          BottomSheetOption(
            title: 'Edit Set',
            icon: Icons.edit,
            onTap: () {
              Navigator.pop(context);
              _editSet(setCategory);
            },
          ),
          BottomSheetOption(
            title: 'Duplicate Set',
            icon: Icons.copy,
            onTap: () {
              Navigator.pop(context);
              _duplicateSet(setCategory);
            },
          ),
          BottomSheetOption(
            title: 'Delete Set',
            icon: Icons.delete,
            onTap: () {
              Navigator.pop(context);
              _deleteSet(setCategory);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _createNewSet() {
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final activeSetsCount = box.values.where((set) => set.isActive).length;

    if (activeSetsCount >= MAX_SETS) {
      showAppSnack(
        context,
        text: 'Maximum of $MAX_SETS workout sets allowed',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditWorkoutSetScreen(position: activeSetsCount),
      ),
    );
  }

  void _editSet(WorkoutSetCategoryModel setCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditWorkoutSetScreen(setCategory: setCategory),
      ),
    );
  }

  void _duplicateSet(WorkoutSetCategoryModel setCategory) {
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final activeSetsCount = box.values.where((set) => set.isActive).length;

    if (activeSetsCount >= MAX_SETS) {
      showAppSnack(
        context,
        text: 'Maximum of $MAX_SETS workout sets allowed',
      );
      return;
    }

    final newSet = WorkoutSetCategoryModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${setCategory.name} (Copy)',
      position: activeSetsCount,
      description: setCategory.description,
      exerciseIds: List.from(setCategory.exerciseIds),
      color: setCategory.color,
      createdAt: DateTime.now(),
    );

    box.add(newSet);

    showAppSnack(
      context,
      text: 'Set duplicated successfully',
      duration: const Duration(seconds: 2),
    );
  }

  void _deleteSet(WorkoutSetCategoryModel setCategory) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Set',
        message:
            'Are you sure you want to delete "${setCategory.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          setCategory.delete();

          // Reorder remaining sets
          final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
          final remainingSets = box.values.where((s) => s.isActive).toList();
          remainingSets.sort((a, b) => a.position.compareTo(b.position));

          for (int i = 0; i < remainingSets.length; i++) {
            remainingSets[i].updatePosition(i);
          }

          showAppSnack(
      context,
      text: 'Set deleted',
    );
        },
      ),
    );
  }

  void _endWorkoutSession() {
    if (widget.activeSession != null) {
      widget.onActiveSessionChanged?.call(null);
      showAppSnack(
        context,
        text: 'Workout session ended',
        duration: const Duration(seconds: 2),
      );
    }
  }
}

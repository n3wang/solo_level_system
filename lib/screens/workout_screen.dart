// lib/screens/workout_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/exercise_details_screen.dart';
import 'package:solo_level_system/screens/add_edit_workout_set_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/utils/workout_service.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/utils/default_workouts_service.dart';
import 'package:solo_level_system/screens/programs_screen.dart';
import 'package:solo_level_system/screens/set_session_summary_screen.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';
import 'package:solo_level_system/screens/workout_summary_screen.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  bool _isLoading = true;
  String? _selectedSetId;
  String _searchQuery = '';
  bool _isSearchVisible = false;
  static const int MAX_SETS = 5;

  // In-progress set session (resume support)
  WorkoutSessionModel? _pausedSetSession;
  List<ExerciseModel>? _pausedSetExercises;
  String? _pausedSetCategoryId;
  int _pausedExerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<WorkoutSetCategoryModel>('workoutSetCategories');
    await _ensureBoxIsOpen<ExerciseModel>('exercises');

    // Ensure default workouts/exercises are initialized first
    try {
      await DefaultWorkoutsService.initializeDefaultWorkouts();
    } catch (e) {
      print('Note: Default workouts may already be initialized: $e');
    }

    // Create 5 default sets if they don't exist
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final activeSets = box.values.where((set) => set.isActive).toList();

    // Default set names and exercises
    final defaultSetNames = [
      'Upper Body Gym',
      'Lower Body Gym',
      'Core Back Body Gym',
      'Home Workout',
      'Outdoor Running',
    ];

    // Default exercises for each set (by name)
    final defaultExercisesBySet = [
      // Set 1: Upper Body Gym
      [
        'Bench press',
        'Pull-ups',
        'Dumbbell bench press',
        'Bicep curls',
        'Overhead press',
      ],
      // Set 2: Lower Body Gym
      ['back squat', 'front squat', 'Leg press', 'Deadlift conventional'],
      // Set 3: Core Back Body Gym
      ['Deadlift conventional', 'Lat pulldown', 'Plank', 'Hanging leg raises'],
      // Set 4: Home Workout
      ['Push-ups', 'Burpees', 'Bodyweight Squats', 'Plank', 'Jumping Jacks'],
      // Set 5: Outdoor Running
      ['Running', 'Treadmill running or walking'],
    ];

    final exercisesBox = Hive.box<ExerciseModel>('exercises');
    final allExercises = exercisesBox.values.toList();

    // Create "Running" exercise if it doesn't exist (for outdoor running)
    final runningExists = allExercises.any(
      (e) =>
          e.name.toLowerCase().contains('running') &&
          !e.name.toLowerCase().contains('treadmill'),
    );

    if (!runningExists) {
      final runningExercise = ExerciseModel(
        id: 'default_exercise_running_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Running',
        description: 'Outdoor running for cardiovascular fitness and endurance',
        category: 'cardio',
        muscleGroup: 'full_body',
        equipment: 'none',
        difficulty: 'beginner',
        instructions: [
          'Start with a warm-up walk',
          'Gradually increase pace to running speed',
          'Maintain steady breathing rhythm',
          'Land on midfoot, not heel',
          'Keep posture upright',
          'Cool down with walking at the end',
        ],
        imageUrl: null,
        isCustom: false,
        createdAt: DateTime.now(),
        tags: ['outdoor', 'cardio'],
        audioFile: null, // No audio file for running
      );
      await exercisesBox.put(runningExercise.id, runningExercise);
      allExercises.add(runningExercise);
    }

    // Helper function to find exercises by name
    List<String> _findExerciseIds(
      List<String> exerciseNames,
      List<ExerciseModel> exercises,
    ) {
      final exerciseIds = <String>[];

      for (final exerciseName in exerciseNames) {
        ExerciseModel? exercise;

        // Try exact match first
        try {
          exercise = exercises.firstWhere(
            (e) =>
                e.name.toLowerCase().trim() ==
                exerciseName.toLowerCase().trim(),
          );
        } catch (e) {
          // Try partial match
          try {
            exercise = exercises.firstWhere(
              (e) =>
                  e.name.toLowerCase().contains(exerciseName.toLowerCase()) ||
                  exerciseName.toLowerCase().contains(e.name.toLowerCase()),
            );
          } catch (e2) {
            // Exercise not found, skip it
            exercise = null;
          }
        }

        // Only add if exercise was found
        if (exercise != null &&
            exercise.id.isNotEmpty &&
            !exerciseIds.contains(exercise.id)) {
          exerciseIds.add(exercise.id);
        }
      }

      return exerciseIds;
    }

    // Create sets if they don't exist, or populate empty sets
    if (activeSets.isEmpty) {
      // Create all 5 sets
      for (int i = 0; i < MAX_SETS; i++) {
        final exerciseIds = _findExerciseIds(
          defaultExercisesBySet[i],
          allExercises,
        );

        final newSet = WorkoutSetCategoryModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          name: defaultSetNames[i],
          position: i,
          description: '',
          exerciseIds: exerciseIds,
          color: AppColorPalette.getColorByIndex(i).value.toString(),
          createdAt: DateTime.now(),
        );
        await box.add(newSet);
      }
    } else {
      // Update existing sets that are empty or have wrong names
      for (int i = 0; i < MAX_SETS; i++) {
        WorkoutSetCategoryModel? existingSet;
        try {
          existingSet = activeSets.firstWhere((set) => set.position == i);
        } catch (e) {
          existingSet = null;
        }

        if (existingSet == null) {
          // Create missing set
          final exerciseIds = _findExerciseIds(
            defaultExercisesBySet[i],
            allExercises,
          );
          final newSet = WorkoutSetCategoryModel(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
            name: defaultSetNames[i],
            position: i,
            description: '',
            exerciseIds: exerciseIds,
            color: AppColorPalette.getColorByIndex(i).value.toString(),
            createdAt: DateTime.now(),
          );
          await box.add(newSet);
        } else if (existingSet.exerciseIds.isEmpty ||
            existingSet.name != defaultSetNames[i]) {
          // Populate empty set or update name
          final exerciseIds = _findExerciseIds(
            defaultExercisesBySet[i],
            allExercises,
          );
          existingSet.exerciseIds = exerciseIds;
          if (existingSet.name != defaultSetNames[i]) {
            existingSet.updateName(defaultSetNames[i]);
          } else {
            existingSet.save();
          }
        }
      }
    }

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
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardTabAppBar(
        controller: _tabController,
        labels: const ['Sets', 'Programs'],
        isScrollable: false,
        visualSlotCount: 4,
      ),
      body: _isLoading
          ? LoadingIndicator(message: 'Loading...')
          : TabBarView(
              controller: _tabController,
              children: [_buildSetsTab(), _buildTimedTab()],
            ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: _tabController.index == 0
          ? _buildSetsFloatingActions()
          : null,
    );
  }

  Widget _buildSetsFloatingActions() {
    final selectedSet = _getSelectedSet();
    final hasExercises =
        selectedSet != null && selectedSet.exerciseIds.isNotEmpty;
    final canResume =
        _pausedSetSession != null &&
        _pausedSetCategoryId == _selectedSetId &&
        _pausedSetExercises != null &&
        _pausedSetExercises!.isNotEmpty;
    final setLabel = _getSelectedSetLabel();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selectedSet != null && (hasExercises || canResume)) ...[
          CustomFloatingActionButton(
            heroTag: 'workout_start_set_session',
            label: canResume ? 'Resume' : 'Start $setLabel',
            icon: canResume ? Icons.play_arrow : Icons.fitness_center,
            onPressed: canResume ? _resumeSetSession : _startSetSession,
          ),
          const SizedBox(height: 12),
        ],
        CustomFloatingActionButton(
          heroTag: 'workout_new_exercise',
          label: 'New E.',
          icon: Icons.add,
          onPressed: _createNewExercise,
        ),
      ],
    );
  }

  WorkoutSetCategoryModel? _getSelectedSet() {
    if (_selectedSetId == null || !Hive.isBoxOpen('workoutSetCategories')) {
      return null;
    }
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    try {
      return box.values.firstWhere((set) => set.id == _selectedSetId);
    } catch (_) {
      return null;
    }
  }

  String _getSelectedSetLabel() {
    final selectedSet = _getSelectedSet();
    if (selectedSet == null) return '';
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final activeSets = box.values.where((set) => set.isActive).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final index = activeSets.indexWhere((set) => set.id == selectedSet.id);
    return index >= 0 ? '${index + 1}' : '${selectedSet.position + 1}';
  }

  List<ExerciseModel> _getOrderedExercisesForSet(
    WorkoutSetCategoryModel setCategory,
  ) {
    if (!Hive.isBoxOpen('exercises')) return [];
    final box = Hive.box<ExerciseModel>('exercises');
    final byId = {for (final e in box.values) e.id: e};
    return setCategory.exerciseIds
        .map((id) => byId[id])
        .whereType<ExerciseModel>()
        .where((e) => !e.isArchived)
        .toList();
  }

  void _startSetSession() {
    final selectedSet = _getSelectedSet();
    if (selectedSet == null) return;

    final exercises = _getOrderedExercisesForSet(selectedSet);
    if (exercises.isEmpty) {
      showAppSnack(
      context,
      text: 'Add an exercise first',
    );
      return;
    }

    _openSetSessionSummary(selectedSet, exercises);
  }

  Future<void> _openSetSessionSummary(
    WorkoutSetCategoryModel selectedSet,
    List<ExerciseModel> exercises, {
    int initialExerciseIndex = 0,
  }) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => SetSessionSummaryScreen(
          setCategory: selectedSet,
          setLabel: _getSelectedSetLabel(),
          exercises: exercises,
          initialExerciseIndex: initialExerciseIndex,
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map<String, dynamic> && result['paused'] == true) {
      setState(() {
        _pausedSetSession = result['session'] as WorkoutSessionModel?;
        _pausedSetExercises =
            (result['exercises'] as List<ExerciseModel>?) ?? exercises;
        _pausedSetCategoryId =
            result['setCategoryId'] as String? ?? selectedSet.id;
        _pausedExerciseIndex = result['exerciseIndex'] as int? ?? 0;
      });
      return;
    }

    // Completed, discarded, or cancelled — clear any pause state
    if (_pausedSetCategoryId == selectedSet.id) {
      setState(() {
        _pausedSetSession = null;
        _pausedSetExercises = null;
        _pausedSetCategoryId = null;
        _pausedExerciseIndex = 0;
      });
    }
  }

  Future<void> _resumeSetSession() async {
    final selectedSet = _getSelectedSet();
    if (selectedSet == null ||
        _pausedSetSession == null ||
        _pausedSetExercises == null) {
      return;
    }

    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutSessionScreen(
          session: _pausedSetSession!,
          exercises: _pausedSetExercises!,
          sequentialMode: true,
          initialExerciseIndex: _pausedExerciseIndex,
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map<String, dynamic> && result['paused'] == true) {
      setState(() {
        _pausedExerciseIndex = result['exerciseIndex'] as int? ?? 0;
      });
      return;
    }

    if (result is Map<String, dynamic> && result['session'] != null) {
      try {
        selectedSet.lastPerformanceDate = DateTime.now();
        selectedSet.modifiedAt = DateTime.now();
        await selectedSet.save();
      } catch (_) {}

      setState(() {
        _pausedSetSession = null;
        _pausedSetExercises = null;
        _pausedSetCategoryId = null;
        _pausedExerciseIndex = 0;
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutSummaryScreen(
            session: result['session'] as WorkoutSessionModel,
            exercises: result['exercises'] as List<ExerciseModel>,
            totalSetsCompleted: result['totalSetsCompleted'] as int,
            totalSets: result['totalSets'] as int,
          ),
        ),
      );
      return;
    }

    // Discarded
    setState(() {
      _pausedSetSession = null;
      _pausedSetExercises = null;
      _pausedSetCategoryId = null;
      _pausedExerciseIndex = 0;
    });
  }

  Widget _buildSetsTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      ).listenable(),
      builder: (context, Box<WorkoutSetCategoryModel> box, _) {
        final allSets = box.values.toList();
        final activeSets = allSets.where((set) => set.isActive).toList();
        activeSets.sort((a, b) => a.position.compareTo(b.position));

        return Column(
          children: [
            _buildSetFilters(activeSets),
            _buildWorkoutHeader(activeSets),
            if (_isSearchVisible) _buildSearchBar(),
            SizedBox(height: 16), // Padding between header and list items
            Expanded(child: _buildExercisesList(activeSets)),
          ],
        );
      },
    );
  }

  Widget _buildSetFilters(List<WorkoutSetCategoryModel> sets) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.5)
            : AppColorPalette.backgroundSurface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: AppColorPalette.grey300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSetFilterChip(
                    label: 'A',
                    isSelected: _selectedSetId == null,
                    onTap: () {
                      setState(() {
                        _selectedSetId = null;
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ...sets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final set = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: _buildSetFilterChip(
                        label: '${index + 1}',
                        isSelected: _selectedSetId == set.id,
                        color: _getSetColor(set),
                        onTap: () {
                          setState(() {
                            _selectedSetId = set.id;
                          });
                        },
                        onLongPress: () => _editSet(set),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.tag),
            tooltip: 'Search by tags',
            onPressed: () {
              setState(() {
                _isSearchVisible = true;
                _searchQuery = 't: ';
                _searchController.text = 't: ';
                // Focus the search field when showing
                Future.delayed(Duration(milliseconds: 100), () {
                  _searchFocusNode.requestFocus();
                  // Move cursor to end after "t: "
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchController.text.length),
                  );
                });
              });
            },
          ),
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (_isSearchVisible) {
                  // Focus the search field when showing
                  Future.delayed(Duration(milliseconds: 100), () {
                    _searchFocusNode.requestFocus();
                  });
                } else {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final chipColor = color ?? AppColorPalette.grey;
    const double verticalPadding = 8;
    const double approximateHeight = 36;
    const double targetWidth = approximateHeight * .8;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBorder = isDark
        ? AppColorPalette.grey300
        : AppColorPalette.grey800;
    final unselectedTextColor = isDark
        ? AppColorPalette.grey300
        : AppColorPalette.grey800;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: targetWidth,
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          border: Border.all(
            color: isSelected ? chipColor : unselectedBorder,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColorPalette.white : unselectedTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutHeader(List<WorkoutSetCategoryModel> sets) {
    // Get the selected set or default to "All"
    WorkoutSetCategoryModel? selectedSet;
    if (_selectedSetId != null && sets.isNotEmpty) {
      try {
        selectedSet = sets.firstWhere((set) => set.id == _selectedSetId);
      } catch (e) {
        selectedSet = null;
      }
    }

    final workoutName = selectedSet != null ? selectedSet.name : 'Any Workout';
    final lastPerformanceDate = selectedSet?.lastPerformanceDate;

    String dateText = 'Never performed';
    if (lastPerformanceDate != null) {
      final now = DateTime.now();
      final difference = now.difference(lastPerformanceDate);

      if (difference.inDays == 0) {
        dateText = 'Today';
      } else if (difference.inDays == 1) {
        dateText = 'Yesterday';
      } else if (difference.inDays < 7) {
        dateText = '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        dateText = weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        dateText = months == 1 ? '1 month ago' : '$months months ago';
      } else {
        final years = (difference.inDays / 365).floor();
        dateText = years == 1 ? '1 year ago' : '$years years ago';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.6)
            : AppColorPalette.grey100.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: AppColorPalette.grey300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workoutName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColorPalette.white
                        : AppColorPalette.grey800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Last performed: $dateText',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColorPalette.grey400
                        : AppColorPalette.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isTagSearch = _searchController.text.startsWith('t: ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: CustomTextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            labelText: 'Search exercises',
            hintText: isTagSearch
                ? 'Enter tag name...'
                : 'Enter exercise name...',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        if (isTagSearch) _buildTagChips(),
      ],
    );
  }

  Widget _buildTagChips() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
      builder: (context, Box<ExerciseModel> box, _) {
        final allExercises = box.values.toList();
        final commonTags = _getMostCommonTags(allExercises, limit: 15);

        if (commonTags.isEmpty) {
          return SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final chipBgColor = isDark
            ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.6)
            : AppColorPalette.grey100.withValues(alpha: 0.8);
        final chipTextColor = isDark
            ? AppColorPalette.grey300
            : AppColorPalette.grey700;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: commonTags.map((tag) {
                return Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      final currentText = _searchController.text;
                      final tagQuery = currentText.startsWith('t: ')
                          ? currentText.substring(3).trim()
                          : '';

                      // If tag is already in query, remove it; otherwise add it
                      final tags = tagQuery.isEmpty
                          ? <String>[]
                          : tagQuery
                                .split(',')
                                .map((t) => t.trim())
                                .where((t) => t.isNotEmpty)
                                .toList();

                      if (tags.contains(tag)) {
                        tags.remove(tag);
                      } else {
                        tags.add(tag);
                      }

                      final newQuery = tags.isEmpty
                          ? 't: '
                          : 't: ${tags.join(', ')}';

                      setState(() {
                        _searchQuery = newQuery;
                        _searchController.text = newQuery;
                        _searchController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: newQuery.length),
                            );
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: chipTextColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: chipTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  List<String> _getMostCommonTags(
    List<ExerciseModel> exercises, {
    int limit = 15,
  }) {
    final tagCounts = <String, int>{};

    for (final exercise in exercises) {
      for (final tag in exercise.tags) {
        final normalizedTag = tag.trim().toLowerCase();
        if (normalizedTag.isNotEmpty) {
          tagCounts[normalizedTag] = (tagCounts[normalizedTag] ?? 0) + 1;
        }
      }
    }

    // Sort by count (descending) and return top tags
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return original tag names (preserving case from first occurrence)
    final tagNameMap = <String, String>{};
    for (final exercise in exercises) {
      for (final tag in exercise.tags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isNotEmpty && !tagNameMap.containsKey(normalized)) {
          tagNameMap[normalized] = tag.trim();
        }
      }
    }

    return sortedTags
        .take(limit)
        .map((entry) => tagNameMap[entry.key] ?? entry.key)
        .toList();
  }

  Widget _buildExercisesList(List<WorkoutSetCategoryModel> sets) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
      builder: (context, Box<ExerciseModel> box, _) {
        final allExercises = box.values.toList();
        final filteredExercises = _filterExercises(allExercises, sets);

        if (allExercises.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center,
            title: 'No Exercises',
            subtitle: 'Create your first exercise to start tracking workouts',
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
            subtitle: _selectedSetId != null
                ? 'No exercises in this set. Long press the set number to add exercises.'
                : 'Try adjusting your search criteria',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredExercises.length,
          itemBuilder: (context, index) {
            final exercise = filteredExercises[index];
            return _buildExerciseCard(exercise, sets);
          },
        );
      },
    );
  }

  Widget _buildExerciseCard(
    ExerciseModel exercise,
    List<WorkoutSetCategoryModel> sets,
  ) {
    final accent = AppColorPalette.color2;
    // Match Sets filter chip aspect: width = height * 0.8 (portrait mini cards).
    const setChipHeight = 12.0;
    const setChipWidth = setChipHeight * 0.8;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _viewExerciseDetails(exercise),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColorPalette.grey300),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Builder(
                          builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final iconBgColor = isDark
                                ? AppColorPalette.backgroundDarkSurface
                                : AppColorPalette.white;
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: WorkoutIconWidget(
                                  key: ValueKey(
                                    'workout_list_icon_${exercise.id}_${exercise.imageUrl}',
                                  ),
                                  imageUrl: exercise.imageUrl,
                                  size: 50,
                                  backgroundColor: iconBgColor,
                                  placeholder: Icon(
                                    _getCategoryIcon(exercise.category),
                                    color: _getCategoryColor(exercise.category),
                                    size: 28,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            final set = sets.length > index
                                ? sets[index]
                                : null;
                            final belongsToSet =
                                set != null &&
                                set.exerciseIds.contains(exercise.id);
                            final setColor = set != null
                                ? _getSetColor(set)
                                : AppColorPalette.grey800;

                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < 4 ? 3 : 0,
                              ),
                              child: Container(
                                width: setChipWidth,
                                height: setChipHeight,
                                decoration: BoxDecoration(
                                  color: belongsToSet
                                      ? setColor
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: belongsToSet
                                        ? setColor
                                        : AppColorPalette.grey800,
                                    width: .6,
                                  ),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildLastWorkoutInfo(exercise),
                              // Space for bookmark in the top-right
                              const SizedBox(width: 28),
                            ],
                          ),
                          if (exercise.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Builder(
                                builder: (context) {
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  return Text(
                                    exercise.description,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColorPalette.grey400
                                          : AppColorPalette.grey600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (exercise.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Builder(
                                builder: (context) {
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  return Text(
                                    't:${exercise.tags.join(', ')}',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColorPalette.grey400
                                          : AppColorPalette.grey600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              exercise.lastWorkoutDate != null
                                  ? _formatLastPerformanceDate(
                                      exercise.lastWorkoutDate!,
                                    )
                                  : 'Never performed',
                              style: TextStyle(
                                fontSize: 11,
                                color: exercise.lastWorkoutDate != null
                                    ? AppColorPalette.textSecondary
                                    : AppColorPalette.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => exercise.toggleBookmark(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      exercise.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 18,
                      color: exercise.isBookmarked
                          ? accent
                          : AppColorPalette.grey400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ExerciseModel> _filterExercises(
    List<ExerciseModel> exercises,
    List<WorkoutSetCategoryModel> sets,
  ) {
    return exercises.where((exercise) {
      // Set filter
      if (_selectedSetId != null) {
        final selectedSet = sets.firstWhere(
          (set) => set.id == _selectedSetId,
          orElse: () => WorkoutSetCategoryModel(
            id: '',
            name: '',
            position: 0,
            exerciseIds: [],
            createdAt: DateTime.now(),
          ),
        );
        if (!selectedSet.exerciseIds.contains(exercise.id)) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();

        // Check if it's a tag search (starts with "t: ")
        if (query.startsWith('t: ')) {
          final tagQuery = query.substring(3).trim();
          if (tagQuery.isEmpty) {
            // If just "t: " with no tag, show all exercises
            return true;
          }
          // Handle multiple tags separated by commas
          final searchTags = tagQuery
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

          // Exercise must have at least one matching tag
          final hasMatchingTag = searchTags.any((searchTag) {
            return exercise.tags.any(
              (tag) => tag.toLowerCase().contains(searchTag),
            );
          });

          if (!hasMatchingTag) {
            return false;
          }
        } else {
          // Regular search in name and description
          if (!exercise.name.toLowerCase().contains(query) &&
              !exercise.description.toLowerCase().contains(query)) {
            return false;
          }
        }
      }

      return true;
    }).toList()..sort((a, b) {
      // Bookmarked exercises appear first
      if (a.isBookmarked && !b.isBookmarked) return -1;
      if (!a.isBookmarked && b.isBookmarked) return 1;
      // Then sort alphabetically by name
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Color _getSetColor(WorkoutSetCategoryModel setCategory) {
    // Always follow the active palette: set 1 → color1, …, set 5 → color5.
    return AppColorPalette.colorForSetPosition(setCategory.position);
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

  String _formatLastPerformanceDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  Widget _buildTimedTab() {
    return ProgramsScreen();
  }

  void _editSet(WorkoutSetCategoryModel setCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditWorkoutSetScreen(setCategory: setCategory),
      ),
    );
  }

  void _createNewExercise() {
    AddEditExerciseScreen.showAsModal(context);
  }

  void _viewExerciseDetails(ExerciseModel exercise) {
    ExerciseDetailsScreen.show(context, exercise);
  }

  Widget _buildLastWorkoutInfo(ExerciseModel exercise) {
    // Get last workout data
    final lastWorkout = WorkoutService.getLastWorkoutData(exercise);
    final unit = exercise.measurementUnit;

    String setsText;
    String? valueText; // Can be null for 'none' type

    if (lastWorkout != null && lastWorkout.reps.isNotEmpty) {
      // Use last workout data
      final numSets = lastWorkout.reps.length;
      setsText = '${numSets}x ';

      // Get values based on measurement type
      final validValues = lastWorkout.weights
          .whereType<double>()
          .where((w) => w > 0)
          .toList();

      if (validValues.isNotEmpty) {
        switch (unit) {
          case 'seconds':
            // Time-based: show average duration
            final avgDuration =
                validValues.reduce((a, b) => a + b) / validValues.length;
            final minutes = (avgDuration / 60).floor();
            final seconds = (avgDuration % 60).round();
            if (minutes > 0) {
              valueText = '${minutes}m ${seconds}s';
            } else {
              valueText = '${seconds}s';
            }
            break;
          case 'none':
            // Bodyweight: no value displayed
            valueText = null;
            break;
          case 'lbs':
            // Weight in pounds
            final avgWeight =
                validValues.reduce((a, b) => a + b) / validValues.length;
            valueText = '${avgWeight.toStringAsFixed(0)}lbs';
            break;
          case 'kg':
          default:
            // Weight in kilograms
            final avgWeight =
                validValues.reduce((a, b) => a + b) / validValues.length;
            valueText = '${avgWeight.toStringAsFixed(0)}kg';
            break;
        }
      } else {
        // No valid values, use defaults based on type
        switch (unit) {
          case 'seconds':
            valueText = '30s';
            break;
          case 'none':
            valueText = null;
            break;
          case 'lbs':
            valueText = '10lbs';
            break;
          case 'kg':
          default:
            valueText = '10kg';
            break;
        }
      }
    } else {
      // Use default values based on measurement type
      setsText = '3x ';
      switch (unit) {
        case 'seconds':
          valueText = '30s';
          break;
        case 'none':
          valueText = null;
          break;
        case 'lbs':
          valueText = '10lbs';
          break;
        case 'kg':
        default:
          valueText = '10kg';
          break;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBgColor = isDark
        ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.6)
        : AppColorPalette.grey100.withValues(alpha: 0.8);
    final textColor = isDark ? AppColorPalette.white : AppColorPalette.grey700;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            setsText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
          if (valueText != null)
            Text(valueText, style: TextStyle(fontSize: 14, color: textColor)),
        ],
      ),
    );
  }
}

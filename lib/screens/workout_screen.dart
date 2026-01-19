// lib/screens/workout_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/exercise_details_screen.dart';
import 'package:solo_level_system/screens/add_edit_workout_set_screen.dart';
import 'package:solo_level_system/screens/motivational_cards_screen.dart';
import 'package:solo_level_system/widgets/common/index.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<WorkoutSetCategoryModel>('workoutSetCategories');
    await _ensureBoxIsOpen<ExerciseModel>('exercises');

    // Create 5 default sets if they don't exist
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final activeSets = box.values.where((set) => set.isActive).toList();

    if (activeSets.isEmpty) {
      for (int i = 0; i < MAX_SETS; i++) {
        final newSet = WorkoutSetCategoryModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          name: 'Set ${i + 1}',
          position: i,
          description: '',
          exerciseIds: [],
          color: AppColorPalette.getColorByIndex(i).value.toString(),
          createdAt: DateTime.now(),
        );
        await box.add(newSet);
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
      appBar: AppBar(
        title: Text('Workout'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColorPalette.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColorPalette.white,
          labelColor: AppColorPalette.white,
          unselectedLabelColor: AppColorPalette.white.withValues(alpha: 0.7),
          tabs: [
            Tab(text: 'Sets'),
            Tab(text: 'Motivation'),
            Tab(text: 'Timed'),
          ],
        ),
      ),
      body: _isLoading
          ? LoadingIndicator(message: 'Loading...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSetsTab(),
                MotivationalCardsScreen(),
                _buildTimedTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? CustomFloatingActionButton(
              label: 'New Exercise',
              icon: Icons.add,
              onPressed: _createNewExercise,
            )
          : null,
    );
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
            if (_isSearchVisible) _buildSearchBar(),
            Expanded(child: _buildExercisesList(activeSets)),
          ],
        );
      },
    );
  }

  Widget _buildSetFilters(List<WorkoutSetCategoryModel> sets) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColorPalette.white,
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? chipColor : AppColorPalette.grey400,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColorPalette.white : AppColorPalette.grey800,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: CustomTextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        labelText: 'Search exercises',
        hintText: 'Enter exercise name...',
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
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
    // Find which sets contain this exercise
    final containingSets = sets
        .where((set) => set.exerciseIds.contains(exercise.id))
        .toList();

    return BaseCard(
      margin: EdgeInsets.only(bottom: 12),
      onTap: () => _viewExerciseDetails(exercise),
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
                      exercise.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (exercise.description.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          exercise.description,
                          style: TextStyle(
                            color: AppColorPalette.grey600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColorPalette.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '3x ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '45kg',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColorPalette.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              // Show set indicators
              if (containingSets.isNotEmpty) ...[
                ...containingSets.take(3).map((set) {
                  final index = sets.indexOf(set);
                  return Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _getSetColor(set).withValues(alpha: 0.2),
                        border: Border.all(color: _getSetColor(set), width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _getSetColor(set),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (containingSets.length > 3)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '+${containingSets.length - 3}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColorPalette.grey,
                      ),
                    ),
                  ),
                Spacer(),
              ],
              Text(
                '[Last Performance data]',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColorPalette.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
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
        if (!exercise.name.toLowerCase().contains(query) &&
            !exercise.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Color _getSetColor(WorkoutSetCategoryModel setCategory) {
    if (setCategory.color != null) {
      try {
        return Color(int.parse(setCategory.color!));
      } catch (e) {
        // Fall through to default colors
      }
    }

    return AppColorPalette.getColorByIndex(setCategory.position);
  }

  Widget _buildTimedTab() {
    return Center(
      child: EmptyState(
        icon: Icons.timer,
        title: 'Timed Workouts',
        subtitle: 'Coming soon - Track time-based exercises',
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

  void _createNewExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditExerciseScreen()),
    );
  }

  void _viewExerciseDetails(ExerciseModel exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailsScreen(exercise: exercise),
      ),
    );
  }
}

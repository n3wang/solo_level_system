// lib/screens/add_edit_routine_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';
import 'package:solo_level_system/models/workout_set_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';

class AddEditRoutineScreen extends StatefulWidget {
  final WorkoutRoutineModel? routine; // null for adding, non-null for editing

  const AddEditRoutineScreen({Key? key, this.routine}) : super(key: key);

  @override
  _AddEditRoutineScreenState createState() => _AddEditRoutineScreenState();
}

class _AddEditRoutineScreenState extends State<AddEditRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedCategory = 'strength';
  String _selectedDifficulty = 'beginner';
  int _estimatedDuration = 30;
  bool _isFavorite = false;

  List<String> _exerciseIds = [];
  Map<String, List<WorkoutSetModel>> _exerciseSets = {};
  List<String> _tags = [];
  List<ExerciseModel> _availableExercises = [];
  List<ExerciseModel> _selectedExercises = [];
  List<ExerciseModel> _filteredExercises = [];
  
  bool _isLoading = false;  final List<String> _categories = [
    'strength',
    'cardio',
    'mixed',
    'custom',
    'powerlifting',
    'bodybuilding',
    'crossfit',
    'functional',
    'hiit',
    'circuit',
    'yoga_flow',
    'stretching',
    'warm_up',
    'cool_down',
    'rehabilitation',
    'sports_specific',
    'other',
  ];

  final List<String> _difficultyLevels = [
    'beginner',
    'intermediate',
    'advanced',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableExercises();
    if (widget.routine != null) {
      _populateFields();
    }
  }

  void _loadAvailableExercises() async {
    final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
    setState(() {
      _availableExercises = exercisesBox.values
          .where((exercise) => !exercise.isArchived)
          .toList();
      _filteredExercises = List.from(_availableExercises);
    });
  }

  void _populateFields() async {
    final routine = widget.routine!;
    _nameController.text = routine.name;
    _descriptionController.text = routine.description;
    _notesController.text = routine.notes ?? '';
    _selectedCategory = routine.category;
    _selectedDifficulty = routine.difficulty;
    _estimatedDuration = routine.estimatedDurationMinutes;
    _isFavorite = routine.isFavorite;
    _exerciseIds = List.from(routine.exerciseIds);
    _exerciseSets = Map.from(routine.exerciseSets);
    _tags = List.from(routine.tags);
    _tagsController.text = _tags.join(', ');

    // Load selected exercises
    final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
    setState(() {
      _selectedExercises = _exerciseIds
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
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.routine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Routine' : 'Create Routine'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRoutine,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    SizedBox(height: 24),
                    _buildCategorySection(),
                    SizedBox(height: 24),
                    _buildExercisesSection(),
                    SizedBox(height: 24),
                    _buildTagsSection(),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Routine Name *',
                hintText: 'e.g., Upper Body Blast, Full Body Strength',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Routine name is required';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of the routine',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Additional notes or tips',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isFavorite,
                  onChanged: (value) => setState(() => _isFavorite = value!),
                ),
                Text('Mark as favorite'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Routine Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDropdownField(
              'Category',
              _selectedCategory,
              _categories,
              (value) => setState(() => _selectedCategory = value!),
              Icons.category,
            ),
            SizedBox(height: 16),
            _buildDropdownField(
              'Difficulty',
              _selectedDifficulty,
              _difficultyLevels,
              (value) => setState(() => _selectedDifficulty = value!),
              Icons.trending_up,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.timer, color: Colors.grey[600], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Duration: ${_estimatedDuration} minutes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Slider(
                        value: _estimatedDuration.toDouble(),
                        min: 10,
                        max: 120,
                        divisions: 22,
                        label: '${_estimatedDuration} min',
                        onChanged: (value) {
                          setState(() => _estimatedDuration = value.round());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Exercises (${_selectedExercises.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: Icon(Icons.add),
                  label: Text('Add Exercise'),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_selectedExercises.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No exercises added yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap "Add Exercise" to get started',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _selectedExercises.length,
                onReorder: _reorderExercises,
                itemBuilder: (context, index) {
                  final exercise = _selectedExercises[index];
                  return _buildExerciseCard(exercise, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise, int index) {
    final sets = _exerciseSets[exercise.id] ?? [];

    return Card(
      key: ValueKey(exercise.id),
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_handle, color: Colors.grey[400]),
                SizedBox(width: 8),
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
                        '${exercise.muscleGroup} • ${exercise.equipment}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings, size: 20),
                  onPressed: () => _configureSets(exercise),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),
            if (sets.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final set = entry.value;
                  return Chip(
                    label: Text(
                      'Set ${setIndex + 1}: ${set.reps} × ${set.weight}kg',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  );
                }).toList(),
              ),
            ] else ...[
              SizedBox(height: 8),
              Text(
                'No sets configured - tap settings to add sets',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tag, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Tags',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Separate tags with commas (e.g., upper body, strength, beginner)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: 'upper body, strength, beginner',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _tags = value
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();
              },
            ),
            if (_tags.isNotEmpty) ...[
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: Colors.green.withOpacity(0.1),
                        side: BorderSide(color: Colors.green.withOpacity(0.3)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(_formatOptionName(option)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  String _formatOptionName(String option) {
    return option
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _addExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildExerciseSelectionSheet(),
    );
  }

  Widget _buildExerciseSelectionSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Select Exercise',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Add Exercise Button
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: _createExerciseFromRoutine,
              icon: Icon(Icons.add),
              label: Text('Create New Exercise'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _filterExercises,
          ),
          SizedBox(height: 16),
          Expanded(
            child: (_filteredExercises.isNotEmpty ? _filteredExercises : _availableExercises).isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No exercises found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first exercise to get started',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: (_filteredExercises.isNotEmpty ? _filteredExercises : _availableExercises).length,
                    itemBuilder: (context, index) {
                      final exercise = (_filteredExercises.isNotEmpty ? _filteredExercises : _availableExercises)[index];
                      final isSelected = _selectedExercises.any(
                        (ex) => ex.id == exercise.id,
                      );

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getMuscleGroupColor(exercise.muscleGroup),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getMuscleGroupIcon(exercise.muscleGroup),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${_formatOptionName(exercise.muscleGroup)} • ${_formatOptionName(exercise.equipment)}',
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : Icon(Icons.add_circle_outline),
                          onTap: isSelected
                              ? null
                              : () {
                                  _selectExercise(exercise);
                                  Navigator.pop(context);
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _selectExercise(ExerciseModel exercise) {
    setState(() {
      _selectedExercises.add(exercise);
      _exerciseIds.add(exercise.id);
      // Initialize with default sets
      _exerciseSets[exercise.id] = [
        WorkoutSetModel(
          id: '${exercise.id}_set_1',
          exerciseId: exercise.id,
          reps: 10,
          weight: 0,
          duration: 0,
          distance: 0,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
      ];
    });
  }

  void _removeExercise(int index) {
    final exercise = _selectedExercises[index];
    setState(() {
      _selectedExercises.removeAt(index);
      _exerciseIds.remove(exercise.id);
      _exerciseSets.remove(exercise.id);
    });
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final exercise = _selectedExercises.removeAt(oldIndex);
      final exerciseId = _exerciseIds.removeAt(oldIndex);
      _selectedExercises.insert(newIndex, exercise);
      _exerciseIds.insert(newIndex, exerciseId);
    });
  }

  void _configureSets(ExerciseModel exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildSetsConfigurationSheet(exercise),
    );
  }

  Widget _buildSetsConfigurationSheet(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id] ?? [];

    return StatefulBuilder(
      builder: (context, setStateModal) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Configure Sets - ${exercise.name}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sets.length,
                  itemBuilder: (context, index) {
                    final set = sets[index];
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Text('Set ${index + 1}'),
                            SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: set.reps.toString(),
                                      decoration: InputDecoration(
                                        labelText: 'Reps',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        set.reps = int.tryParse(value) ?? 0;
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: set.weight.toString(),
                                      decoration: InputDecoration(
                                        labelText: 'Weight (kg)',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        set.weight =
                                            double.tryParse(value) ?? 0;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setStateModal(() {
                                  sets.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setStateModal(() {
                          sets.add(
                            WorkoutSetModel(
                              id: '${exercise.id}_set_${sets.length + 1}',
                              exerciseId: exercise.id,
                              reps: 10,
                              weight: 0,
                              restTimeSeconds: 60,
                              isCompleted: false,
                            ),
                          );
                        });
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add Set'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _exerciseSets[exercise.id] = sets;
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  void _saveRoutine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routinesBox = await Hive.openBox<WorkoutRoutineModel>(
        'workoutRoutines',
      );

      final routineData = WorkoutRoutineModel(
        id:
            widget.routine?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        exerciseIds: _exerciseIds,
        exerciseSets: _exerciseSets,
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        estimatedDurationMinutes: _estimatedDuration,
        tags: _tags,
        isTemplate: true,
        isFavorite: _isFavorite,
        createdAt: widget.routine?.createdAt ?? DateTime.now(),
        modifiedAt: widget.routine != null ? DateTime.now() : null,
        timesCompleted: widget.routine?.timesCompleted ?? 0,
        lastCompletedAt: widget.routine?.lastCompletedAt,
        isArchived: widget.routine?.isArchived ?? false,
        notes: _notesController.text.trim(),
        targetMuscleGroups: _selectedExercises
            .map((ex) => ex.muscleGroup)
            .toSet()
            .toList(),
        createdBy: 'user',
      );

      if (widget.routine != null) {
        // Update existing routine
        final index = routinesBox.values.toList().indexWhere(
          (routine) => routine.id == widget.routine!.id,
        );
        if (index != -1) {
          await routinesBox.putAt(index, routineData);
        }
      } else {
        // Add new routine
        await routinesBox.add(routineData);
      }

      Navigator.pop(context, true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.routine != null
                ? 'Routine updated successfully'
                : 'Routine created successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving routine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createExerciseFromRoutine() async {
    // Save current routine state before navigating
    final routineState = _saveCurrentRoutineState();
    
    Navigator.pop(context); // Close exercise selection sheet
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExerciseScreen(),
      ),
    );
    
    if (result == true) {
      // Restore routine state and reload exercises
      _restoreRoutineState(routineState);
      _loadAvailableExercises();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise created! You can now add it to your routine.')),
      );
      
      // Reopen exercise selection with new exercise available
      _addExercise();
    }
  }

  Map<String, dynamic> _saveCurrentRoutineState() {
    return {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'notes': _notesController.text,
      'tags': _tagsController.text,
      'category': _selectedCategory,
      'difficulty': _selectedDifficulty,
      'duration': _estimatedDuration,
      'isFavorite': _isFavorite,
      'selectedExercises': _selectedExercises.map((e) => e.id).toList(),
      'exerciseSets': _exerciseSets,
    };
  }

  void _restoreRoutineState(Map<String, dynamic> state) {
    _nameController.text = state['name'] ?? '';
    _descriptionController.text = state['description'] ?? '';
    _notesController.text = state['notes'] ?? '';
    _tagsController.text = state['tags'] ?? '';
    _selectedCategory = state['category'] ?? 'strength';
    _selectedDifficulty = state['difficulty'] ?? 'beginner';
    _estimatedDuration = state['duration'] ?? 30;
    _isFavorite = state['isFavorite'] ?? false;
    _exerciseSets = Map<String, List<WorkoutSetModel>>.from(state['exerciseSets'] ?? {});
    
    // Restore selected exercises
    final selectedIds = List<String>.from(state['selectedExercises'] ?? []);
    _selectedExercises = _availableExercises
        .where((exercise) => selectedIds.contains(exercise.id))
        .toList();
    _exerciseIds = selectedIds;
    
    // Restore tags
    _tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
        
    setState(() {});
  }

  void _filterExercises(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredExercises = List.from(_availableExercises);
      } else {
        _filteredExercises = _availableExercises
            .where((exercise) =>
                exercise.name.toLowerCase().contains(query.toLowerCase()) ||
                exercise.muscleGroup.toLowerCase().contains(query.toLowerCase()) ||
                exercise.category.toLowerCase().contains(query.toLowerCase()) ||
                exercise.equipment.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
}

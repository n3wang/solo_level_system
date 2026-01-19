// lib/screens/add_edit_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';

class AddEditExerciseScreen extends StatefulWidget {
  final ExerciseModel? exercise; // null for adding, non-null for editing

  const AddEditExerciseScreen({super.key, this.exercise});

  @override
  _AddEditExerciseScreenState createState() => _AddEditExerciseScreenState();
}

class _AddEditExerciseScreenState extends State<AddEditExerciseScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TabController _tabController;

  // Default workout data
  int _defaultSets = 3;
  double _defaultWeight = 10.0;
  final Set<String> _selectedSetIds = {};

  List<String> _tags = [];
  bool _isLoading = false;
  bool _showOptionalFields = false;
  String _measurementUnit = 'kg'; // 'kg', 'lbs', 'seconds', 'none'

  final List<String> _measurementUnits = ['kg', 'lbs', 'seconds', 'none'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.exercise != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final exercise = widget.exercise!;
    _nameController.text = exercise.name;
    _descriptionController.text = exercise.description;
    _tags = List.from(exercise.tags);
    _tagsController.text = _tags.join(', ');
    _measurementUnit = exercise.measurementUnit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exercise != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Exercise' : 'Create Exercise'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColorPalette.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExercise,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColorPalette.info,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColorPalette.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
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
                    // Exercise Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'e.g., Pushups, Bench Press',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Exercise name is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Default Workout Sets Section (includes measurement unit selector)
                    _buildDefaultWorkoutSection(),
                    SizedBox(height: 16),

                    // Sets Selection
                    _buildSetsSelectionSection(),
                    SizedBox(height: 24),

                    // Optional Section Toggle
                    _buildOptionalSectionToggle(),

                    if (_showOptionalFields) ...[
                      SizedBox(height: 16),
                      _buildOptionalFields(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  void _cycleMeasurementUnit() {
    setState(() {
      final currentIndex = _measurementUnits.indexOf(_measurementUnit);
      final nextIndex = (currentIndex + 1) % _measurementUnits.length;
      _measurementUnit = _measurementUnits[nextIndex];

      // Reset default weight/duration based on unit
      if (_measurementUnit == 'seconds') {
        _defaultWeight = 30.0; // Default 30 seconds
      } else if (_measurementUnit == 'none') {
        _defaultWeight = 0.0; // No weight for bodyweight
      } else {
        _defaultWeight = 10.0; // Default 10kg or 10lbs
      }
    });
  }

  String _getMeasurementUnitDisplayText() {
    switch (_measurementUnit) {
      case 'kg':
        return 'kg';
      case 'lbs':
        return 'lbs';
      case 'seconds':
        return 'time';
      case 'none':
        return 'bodyweight';
      default:
        return _measurementUnit;
    }
  }

  Widget _buildDefaultWorkoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark, size: 20, color: AppColorPalette.grey600),
            SizedBox(width: 8),
            Text(
              'Default workout',
              style: TextStyle(
                fontSize: 14,
                color: AppColorPalette.grey700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            // Measurement unit selector (tap to change)
            GestureDetector(
              onTap: _cycleMeasurementUnit,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColorPalette.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColorPalette.info, width: 1.5),
                ),
                child: Text(
                  _getMeasurementUnitDisplayText(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColorPalette.info,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Sets input (only show if not bodyweight-only)
            if (_measurementUnit != 'none') ...[
              Container(
                width: 50,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColorPalette.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColorPalette.success),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  controller: TextEditingController(
                    text: _defaultSets.toString(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() => _defaultSets = parsed);
                    }
                  },
                ),
              ),
              SizedBox(width: 8),
              // x separator
              Text(
                'x',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              // Weight/Duration input
              Container(
                width: 60,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColorPalette.grey400),
                ),
                child: TextField(
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: _measurementUnit != 'seconds',
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  controller: TextEditingController(
                    text: _measurementUnit == 'seconds'
                        ? _defaultWeight.toInt().toString()
                        : _defaultWeight.toString(),
                  ),
                  onChanged: (value) {
                    final parsed = _measurementUnit == 'seconds'
                        ? int.tryParse(value)?.toDouble()
                        : double.tryParse(value);
                    if (parsed != null) {
                      setState(() => _defaultWeight = parsed);
                    }
                  },
                ),
              ),
              SizedBox(width: 4),
              // Unit label
              Text(
                _measurementUnit == 'seconds' ? 's' : _measurementUnit,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColorPalette.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              // For bodyweight, just show sets
              Container(
                width: 50,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColorPalette.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColorPalette.success),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'Sets',
                  ),
                  controller: TextEditingController(
                    text: _defaultSets.toString(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() => _defaultSets = parsed);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSetsSelectionSection() {
    final box = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories');
    final sets = box.values.where((s) => s.isActive).toList();
    sets.sort((a, b) => a.position.compareTo(b.position));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view, size: 20, color: AppColorPalette.grey600),
            SizedBox(width: 8),
            Text(
              'Sets',
              style: TextStyle(
                fontSize: 14,
                color: AppColorPalette.grey700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            final isSelected = _selectedSetIds.contains(set.id);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSetIds.remove(set.id);
                  } else {
                    _selectedSetIds.add(set.id);
                  }
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColorPalette.grey800
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColorPalette.grey800
                        : AppColorPalette.grey400,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isSelected
                          ? AppColorPalette.white
                          : AppColorPalette.grey800,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedSetIds.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Toggled on set names: ${_getSelectedSetNames(sets)}',
            style: TextStyle(fontSize: 11, color: AppColorPalette.grey600),
          ),
        ],
      ],
    );
  }

  String _getSelectedSetNames(List<WorkoutSetCategoryModel> sets) {
    return _selectedSetIds
        .map((id) {
          final set = sets.firstWhere((s) => s.id == id);
          return set.name;
        })
        .join(', ');
  }

  Widget _buildOptionalSectionToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showOptionalFields = !_showOptionalFields;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColorPalette.grey300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              'Optional',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColorPalette.grey700,
              ),
            ),
            Spacer(),
            Icon(
              _showOptionalFields ? Icons.expand_less : Icons.expand_more,
              color: AppColorPalette.grey600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image placeholder
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppColorPalette.grey100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColorPalette.grey300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 32, color: AppColorPalette.grey400),
                SizedBox(height: 4),
                Text(
                  'Image',
                  style: TextStyle(
                    color: AppColorPalette.grey600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // Tags (Category, Muscle Group, and Tags combined)
        TextFormField(
          controller: _tagsController,
          decoration: InputDecoration(
            labelText: 'Category, Muscle Group, and Tags',
            hintText: 'e.g., strength, chest, compound, beginner',
            border: OutlineInputBorder(),
            helperText: 'Separate with commas',
          ),
          onChanged: (value) {
            _tags = value
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();
          },
        ),
        SizedBox(height: 16),

        // Description / Instructions Tabs
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColorPalette.grey300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColorPalette.info,
                unselectedLabelColor: AppColorPalette.grey,
                indicatorColor: AppColorPalette.info,
                tabs: [
                  Tab(text: 'Description'),
                  Tab(text: 'Instructions'),
                ],
              ),
              Container(
                height: 200,
                padding: EdgeInsets.all(12),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter exercise description...',
                      ),
                      maxLines: null,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter step-by-step instructions...',
                      ),
                      maxLines: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
      final setsBox = await Hive.openBox<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      );

      final exerciseData = ExerciseModel(
        id:
            widget.exercise?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _tags.isNotEmpty ? _tags.first : 'other',
        muscleGroup: _tags.length > 1 ? _tags[1] : 'other',
        equipment: 'other',
        difficulty: 'intermediate',
        instructions: [],
        isCustom: true,
        createdAt: widget.exercise?.createdAt ?? DateTime.now(),
        modifiedAt: widget.exercise != null ? DateTime.now() : null,
        tags: _tags,
        isArchived: widget.exercise?.isArchived ?? false,
        measurementUnit: _measurementUnit,
      );

      String exerciseId;
      if (widget.exercise != null) {
        // Update existing exercise
        final index = exercisesBox.values.toList().indexWhere(
          (ex) => ex.id == widget.exercise!.id,
        );
        if (index != -1) {
          await exercisesBox.putAt(index, exerciseData);
          exerciseId = widget.exercise!.id;
        } else {
          exerciseId = exerciseData.id;
        }
      } else {
        // Add new exercise
        await exercisesBox.add(exerciseData);
        exerciseId = exerciseData.id;
      }

      // Add exercise to selected sets
      for (var setId in _selectedSetIds) {
        final set = setsBox.values.firstWhere((s) => s.id == setId);
        if (!set.exerciseIds.contains(exerciseId)) {
          set.addExercise(exerciseId);
        }
      }

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.exercise != null
                ? 'Exercise updated successfully'
                : 'Exercise created successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving exercise: $e'),
          backgroundColor: AppColorPalette.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

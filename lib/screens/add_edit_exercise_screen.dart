// lib/screens/add_edit_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/exercise_model.dart';

class AddEditExerciseScreen extends StatefulWidget {
  final ExerciseModel? exercise; // null for adding, non-null for editing

  const AddEditExerciseScreen({super.key, this.exercise});

  @override
  _AddEditExerciseScreenState createState() => _AddEditExerciseScreenState();
}

class _AddEditExerciseScreenState extends State<AddEditExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedCategory = 'strength';
  String _selectedMuscleGroup = 'chest';
  String _selectedEquipment = 'bodyweight';
  String _selectedDifficulty = 'beginner';

  List<String> _instructions = [];
  List<String> _tags = [];

  bool _isLoading = false;

  final List<String> _categories = [
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
    'martial_arts',
    'dance',
    'rehabilitation',
    'warm_up',
    'cool_down',
    'other',
  ];

  final List<String> _muscleGroups = [
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
  ];

  final List<String> _equipmentOptions = [
    'bodyweight',
    'dumbbells',
    'barbell',
    'machine',
    'cables',
    'resistance_bands',
    'kettlebell',
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
    if (widget.exercise != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final exercise = widget.exercise!;
    _nameController.text = exercise.name;
    _descriptionController.text = exercise.description;
    _selectedCategory = exercise.category;
    _selectedMuscleGroup = exercise.muscleGroup;
    _selectedEquipment = exercise.equipment;
    _selectedDifficulty = exercise.difficulty;
    _instructions = List.from(exercise.instructions);
    _tags = List.from(exercise.tags);
    _instructionsController.text = _instructions.join('\n');
    _tagsController.text = _tags.join(', ');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exercise != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Exercise' : 'Add Exercise'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExercise,
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
                    _buildDetailsSection(),
                    SizedBox(height: 24),
                    _buildInstructionsSection(),
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
                labelText: 'Exercise Name *',
                hintText: 'e.g., Push-ups, Bench Press',
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
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of the exercise',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              'Category & Target',
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
              'Muscle Group',
              _selectedMuscleGroup,
              _muscleGroups,
              (value) => setState(() => _selectedMuscleGroup = value!),
              Icons.accessibility,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDropdownField(
              'Equipment',
              _selectedEquipment,
              _equipmentOptions,
              (value) => setState(() => _selectedEquipment = value!),
              Icons.fitness_center,
            ),
            SizedBox(height: 16),
            _buildDropdownField(
              'Difficulty',
              _selectedDifficulty,
              _difficultyLevels,
              (value) => setState(() => _selectedDifficulty = value!),
              Icons.trending_up,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Enter each step on a new line',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText:
                    'Step 1: Position yourself...\nStep 2: Lower your body...\nStep 3: Push back up...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              onChanged: (value) {
                _instructions = value
                    .split('\n')
                    .where((line) => line.trim().isNotEmpty)
                    .toList();
              },
            ),
            if (_instructions.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Preview:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              ..._instructions.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
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
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
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
              'Separate tags with commas (e.g., compound, upper body, beginner)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: 'compound, upper body, beginner',
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
            initialValue: value,
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

  void _saveExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');

      final exerciseData = ExerciseModel(
        id:
            widget.exercise?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        muscleGroup: _selectedMuscleGroup,
        equipment: _selectedEquipment,
        difficulty: _selectedDifficulty,
        instructions: _instructions,
        isCustom: true,
        createdAt: widget.exercise?.createdAt ?? DateTime.now(),
        modifiedAt: widget.exercise != null ? DateTime.now() : null,
        tags: _tags,
        isArchived: widget.exercise?.isArchived ?? false,
      );

      if (widget.exercise != null) {
        // Update existing exercise
        final index = exercisesBox.values.toList().indexWhere(
          (ex) => ex.id == widget.exercise!.id,
        );
        if (index != -1) {
          await exercisesBox.putAt(index, exerciseData);
        }
      } else {
        // Add new exercise
        await exercisesBox.add(exerciseData);
      }

      Navigator.pop(context, true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.exercise != null
                ? 'Exercise updated successfully'
                : 'Exercise added successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving exercise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

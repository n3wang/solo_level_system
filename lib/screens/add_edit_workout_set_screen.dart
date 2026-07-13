// lib/screens/add_edit_workout_set_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class AddEditWorkoutSetScreen extends StatefulWidget {
  final WorkoutSetCategoryModel? setCategory;
  final int? position;

  const AddEditWorkoutSetScreen({super.key, this.setCategory, this.position});

  @override
  _AddEditWorkoutSetScreenState createState() =>
      _AddEditWorkoutSetScreenState();
}

class _AddEditWorkoutSetScreenState extends State<AddEditWorkoutSetScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  Color? _selectedColor;
  bool _isSaving = false;

  final List<Color> _availableColors = [
    Colors.purple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.setCategory != null) {
      _nameController = TextEditingController(text: widget.setCategory!.name);
      _descriptionController = TextEditingController(
        text: widget.setCategory!.description,
      );
      if (widget.setCategory!.color != null) {
        try {
          _selectedColor = Color(int.parse(widget.setCategory!.color!));
        } catch (e) {
          _selectedColor = null;
        }
      }
    } else {
      final position = widget.position ?? 0;
      _nameController = TextEditingController(text: 'Set ${position + 1}');
      _descriptionController = TextEditingController();
      _selectedColor = _availableColors[position % _availableColors.length];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.setCategory != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Workout Set' : 'New Workout Set'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            CustomTextField(
              controller: _nameController,
              labelText: 'Set Name',
              hintText: 'e.g., Set 1, Morning Routine, etc.',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name for this set';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              labelText: 'Description (Optional)',
              hintText: 'Describe what exercises belong in this set',
              maxLines: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Set Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),
            _buildColorPicker(),
            SizedBox(height: 32),
            if (isEditing) ...[_buildInfoCard(), SizedBox(height: 24)],
            PrimaryActionButton(
              text: isEditing ? 'Update Set' : 'Create Set',
              icon: isEditing ? Icons.check : Icons.add,
              onPressed: _isSaving ? null : _saveSet,
              isLoading: _isSaving,
            ),
            SizedBox(height: 16),
            SecondaryActionButton(
              text: 'Cancel',
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableColors.map((color) {
        final isSelected = _selectedColor == color;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha:0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check, color: Colors.white, size: 30)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard() {
    final exerciseCount = widget.setCategory!.exerciseIds.length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Set Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildInfoRow('Exercises', '$exerciseCount'),
          SizedBox(height: 8),
          _buildInfoRow('Created', _formatDate(widget.setCategory!.createdAt)),
          if (widget.setCategory!.modifiedAt != null) ...[
            SizedBox(height: 8),
            _buildInfoRow(
              'Modified',
              _formatDate(widget.setCategory!.modifiedAt!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColorPalette.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _saveSet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final box = await Hive.openBox<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      );

      if (widget.setCategory != null) {
        // Update existing set
        widget.setCategory!.updateName(_nameController.text.trim());
        widget.setCategory!.updateDescription(
          _descriptionController.text.trim(),
        );
        widget.setCategory!.color = _selectedColor?.value.toString();
        widget.setCategory!.modifiedAt = DateTime.now();
        await widget.setCategory!.save();
      } else {
        // Create new set
        final newSet = WorkoutSetCategoryModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          position: widget.position ?? 0,
          description: _descriptionController.text.trim(),
          exerciseIds: [],
          color: _selectedColor?.value.toString(),
          createdAt: DateTime.now(),
        );

        await box.add(newSet);
      }

      if (mounted) {
        showAppSnack(
          context,
          text: widget.setCategory != null
                  ? 'Set updated successfully'
                  : 'Set created successfully',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          text: 'Error saving set: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

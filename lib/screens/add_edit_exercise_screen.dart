// lib/screens/add_edit_exercise_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/widgets/exercise_image_library_picker.dart';
import 'package:solo_level_system/widgets/exercise_set_membership_toggle.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/widgets/common/centered_app_modal.dart';

class AddEditExerciseScreen extends StatefulWidget {
  final ExerciseModel? exercise; // null for adding, non-null for editing
  final bool presentedAsModal;

  const AddEditExerciseScreen({
    super.key,
    this.exercise,
    this.presentedAsModal = false,
  });

  /// Centered modal. Returns:
  /// - `true` on save
  /// - `'discard'` on back
  /// - `'duplicated'` after duplicate
  /// - `null` when dismissed by tapping outside
  static Future<Object?> showAsModal(
    BuildContext context, {
    ExerciseModel? exercise,
  }) {
    return showCenteredAppModal<Object?>(
      context: context,
      builder: (ctx) => AddEditExerciseScreen(
        exercise: exercise,
        presentedAsModal: true,
      ),
    );
  }

  @override
  _AddEditExerciseScreenState createState() => _AddEditExerciseScreenState();
}

class _AddEditExerciseScreenState extends State<AddEditExerciseScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();

  late TabController _tabController;

  /// Exercise currently being edited (may switch after duplicate).
  ExerciseModel? _workingExercise;

  final Set<String> _selectedSetIds = {};

  List<String> _tags = [];
  bool _isLoading = false;
  bool _showOptionalFields = true;
  bool _isBookmarked = false;
  String _measurementUnit = 'kg';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _workingExercise = widget.exercise;
    if (_workingExercise != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final exercise = _workingExercise!;
    _nameController.text = exercise.name;
    _descriptionController.text = exercise.description;
    _instructionsController.text = exercise.instructions.join('\n');
    _tags = List.from(exercise.tags);
    _tagsController.text = _tags.join(', ');
    _measurementUnit = exercise.measurementUnit;
    _isBookmarked = exercise.isBookmarked;
    _imageUrl = exercise.imageUrl;

    _selectedSetIds.clear();
    if (Hive.isBoxOpen('workoutSetCategories')) {
      final sets = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories')
          .values
          .where((s) => s.isActive && s.exerciseIds.contains(exercise.id));
      _selectedSetIds.addAll(sets.map((s) => s.id));
    }
  }

  List<String> _parseInstructions() {
    return _instructionsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _discard() {
    Navigator.pop(context, 'discard');
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _workingExercise != null;

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit' : 'Create'),
        backgroundColor: widget.presentedAsModal
            ? Theme.of(context).scaffoldBackgroundColor
            : Theme.of(context).primaryColor,
        foregroundColor: widget.presentedAsModal
            ? Theme.of(context).colorScheme.onSurface
            : AppColorPalette.white,
        elevation: widget.presentedAsModal ? 0 : null,
        scrolledUnderElevation: widget.presentedAsModal ? 0 : null,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Discard',
          onPressed: _isLoading ? null : _discard,
        ),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _isBookmarked = !_isBookmarked;
                    });
                  },
            tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
          ),
          if (isEditing)
            TextButton.icon(
              onPressed: _isLoading ? null : _duplicateExercise,
              icon: Icon(
                Icons.copy_outlined,
                color: widget.presentedAsModal
                    ? Theme.of(context).colorScheme.onSurface
                    : AppColorPalette.white,
              ),
              label: Text(
                'Duplicate',
                style: TextStyle(
                  color: widget.presentedAsModal
                      ? Theme.of(context).colorScheme.onSurface
                      : AppColorPalette.white,
                ),
              ),
            ),
          TextButton(
            onPressed: _isLoading ? null : _saveExercise,
            child: Text(
              'Save',
              style: TextStyle(
                color: widget.presentedAsModal
                    ? Theme.of(context).primaryColor
                    : AppColorPalette.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name*',
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
                    const SizedBox(height: 16),
                    ExerciseSetMembershipToggle(
                      selectedSetIds: _selectedSetIds,
                      onChanged: (next) {
                        setState(() {
                          _selectedSetIds
                            ..clear()
                            ..addAll(next);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildOptionalSectionToggle(),
                    if (_showOptionalFields) ...[
                      const SizedBox(height: 16),
                      _buildOptionalFields(),
                    ],
                  ],
                ),
              ),
            ),
    );

    return scaffold;
  }

  Widget _buildOptionalSectionToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showOptionalFields = !_showOptionalFields;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
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
            const Spacer(),
            Icon(
              _showOptionalFields ? Icons.expand_less : Icons.expand_more,
              color: AppColorPalette.textSecondary,
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
        _buildImageSection(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tagsController,
          decoration: const InputDecoration(
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
        const SizedBox(height: 16),
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
                tabs: const [
                  Tab(text: 'Description'),
                  Tab(text: 'Instructions'),
                ],
              ),
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter exercise description...',
                      ),
                      maxLines: null,
                    ),
                    TextField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Enter step-by-step instructions (one per line)...',
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColorPalette.grey700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColorPalette.grey100,
                borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
                border: Border.all(color: AppColorPalette.grey300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageUrl == null || _imageUrl!.isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: AppColorPalette.textSecondary,
                    )
                  : WorkoutIconWidget(imageUrl: _imageUrl, size: 96),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickFromPhoneLibrary,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Phone library'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickFromExerciseLibrary,
                      icon: const Icon(Icons.fitness_center, size: 18),
                      label: const Text('Exercise images'),
                    ),
                  ),
                  if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _imageUrl = null),
                        child: const Text('Remove image'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickFromPhoneLibrary() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone library is not available on web')),
      );
      return;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          // Fall through — image_picker may still work via system picker
        }
      }

      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final exerciseDir = Directory('${dir.path}/exercise_images');
      if (!await exerciseDir.exists()) {
        await exerciseDir.create(recursive: true);
      }
      final fileName =
          'exercise_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(picked.path).copy('${exerciseDir.path}/$fileName');

      if (!mounted) return;
      setState(() => _imageUrl = saved.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _pickFromExerciseLibrary() async {
    final slug = await ExerciseImageLibraryPicker.show(context);
    if (slug == null || !mounted) return;
    setState(() => _imageUrl = slug);
  }

  Future<void> _syncSetMembership(String exerciseId) async {
    final setsBox = await Hive.openBox<WorkoutSetCategoryModel>(
      'workoutSetCategories',
    );

    for (final set in setsBox.values) {
      final shouldBelong = _selectedSetIds.contains(set.id);
      final belongs = set.exerciseIds.contains(exerciseId);
      if (shouldBelong && !belongs) {
        set.addExercise(exerciseId);
      } else if (!shouldBelong && belongs) {
        set.removeExercise(exerciseId);
      }
    }
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final wasUpdate = _workingExercise != null;

    try {
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
      final instructions = _parseInstructions();
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      String exerciseId;

      if (_workingExercise != null) {
        ExerciseModel boxed = _workingExercise!;
        if (!boxed.isInBox) {
          boxed = exercisesBox.values.firstWhere(
            (ex) => ex.id == boxed.id,
            orElse: () => boxed,
          );
        }

        boxed.name = name;
        boxed.description = description;
        boxed.category = _tags.isNotEmpty ? _tags.first : boxed.category;
        boxed.muscleGroup = _tags.length > 1 ? _tags[1] : boxed.muscleGroup;
        boxed.instructions = instructions;
        boxed.modifiedAt = DateTime.now();
        boxed.tags = _tags;
        boxed.measurementUnit = _measurementUnit;
        boxed.isBookmarked = _isBookmarked;
        boxed.imageUrl = _imageUrl;

        if (boxed.isInBox) {
          await boxed.save();
        } else {
          await exercisesBox.put(boxed.id, boxed);
        }
        exerciseId = boxed.id;
        _workingExercise = boxed;
      } else {
        final exerciseData = ExerciseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          description: description,
          category: _tags.isNotEmpty ? _tags.first : 'other',
          muscleGroup: _tags.length > 1 ? _tags[1] : 'other',
          equipment: 'other',
          difficulty: 'intermediate',
          instructions: instructions,
          isCustom: true,
          createdAt: DateTime.now(),
          tags: _tags,
          isArchived: false,
          measurementUnit: _measurementUnit,
          isBookmarked: _isBookmarked,
          imageUrl: _imageUrl,
        );
        await exercisesBox.put(exerciseData.id, exerciseData);
        exerciseId = exerciseData.id;
        _workingExercise = exerciseData;
      }

      await _syncSetMembership(exerciseId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasUpdate
                ? 'Exercise updated successfully'
                : 'Exercise created successfully',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving exercise: $e'),
          backgroundColor: AppColorPalette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _duplicateExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exercisesBox = await Hive.openBox<ExerciseModel>('exercises');
      final source = _workingExercise!;
      final baseName = _nameController.text.trim();
      final copyName = baseName.endsWith('(Copy)')
          ? baseName
          : '$baseName (Copy)';

      final duplicate = ExerciseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: copyName,
        description: _descriptionController.text.trim(),
        category: _tags.isNotEmpty ? _tags.first : source.category,
        muscleGroup: _tags.length > 1 ? _tags[1] : source.muscleGroup,
        equipment: source.equipment,
        difficulty: source.difficulty,
        instructions: _parseInstructions(),
        videoUrl: source.videoUrl,
        imageUrl: _imageUrl ?? source.imageUrl,
        isCustom: true,
        createdAt: DateTime.now(),
        tags: List.from(_tags),
        isArchived: false,
        measurementUnit: _measurementUnit,
        isBookmarked: false,
        audioFile: source.audioFile,
      );

      await exercisesBox.put(duplicate.id, duplicate);

      // Copy current set selection onto the duplicate
      final setsBox = await Hive.openBox<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      );
      for (final setId in _selectedSetIds) {
        final match = setsBox.values.where((s) => s.id == setId);
        if (match.isNotEmpty) {
          match.first.addExercise(duplicate.id);
        }
      }

      if (!mounted) return;
      setState(() {
        _workingExercise = duplicate;
        _nameController.text = duplicate.name;
        _imageUrl = duplicate.imageUrl;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise duplicated — editing copy')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error duplicating exercise: $e'),
          backgroundColor: AppColorPalette.error,
        ),
      );
    }
  }
}

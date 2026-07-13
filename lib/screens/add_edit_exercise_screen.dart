// lib/screens/add_edit_exercise_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/utils/exercise_tag_semantics.dart';
import 'package:solo_level_system/widgets/exercise_image_library_picker.dart';
import 'package:solo_level_system/widgets/exercise_set_membership_toggle.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/widgets/common/centered_app_modal.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

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
  ///
  /// Set [nested] when opening over another centered modal (e.g. from
  /// exercise details) so the backdrop is not dimmed twice.
  static Future<Object?> showAsModal(
    BuildContext context, {
    ExerciseModel? exercise,
    bool nested = false,
  }) {
    return showCenteredAppModal<Object?>(
      context: context,
      barrierColor: nested ? Colors.transparent : null,
      builder: (ctx) =>
          AddEditExerciseScreen(exercise: exercise, presentedAsModal: true),
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
  List<String> _tagSuggestions = [];
  final Set<String> _knownTagsCatalog = {...ExerciseTagSemantics.catalogTags};
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
    _loadKnownTagsFromDatabase();
    if (_workingExercise != null) {
      _populateFields();
    }
  }

  Future<void> _loadKnownTagsFromDatabase() async {
    try {
      if (!Hive.isBoxOpen('exercises')) {
        await Hive.openBox<ExerciseModel>('exercises');
      }
      if (!mounted) return;
      setState(() {
        for (final exercise in Hive.box<ExerciseModel>('exercises').values) {
          for (final tag in exercise.tags) {
            final normalized = tag.trim().toLowerCase();
            if (normalized.isNotEmpty) _knownTagsCatalog.add(normalized);
          }
          for (final extra in [
            exercise.category,
            exercise.muscleGroup,
            exercise.equipment,
            exercise.difficulty,
          ]) {
            final normalized = extra.trim().toLowerCase();
            if (normalized.isNotEmpty) _knownTagsCatalog.add(normalized);
          }
        }
      });
    } catch (_) {
      // Catalog still has built-in special tags.
    }
  }

  void _populateFields() {
    final exercise = _workingExercise!;
    _nameController.text = exercise.name;
    _descriptionController.text = exercise.description;
    _instructionsController.text = exercise.instructions.join('\n');
    _tags = ExerciseTagSemantics.buildTags(
      existing: exercise.tags,
      category: exercise.category,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
      difficulty: exercise.difficulty,
    );
    _tagsController.text = _tags.join(', ');
    _measurementUnit = exercise.measurementUnit;
    _isBookmarked = exercise.isBookmarked;
    _imageUrl = exercise.imageUrl;

    _selectedSetIds.clear();
    if (Hive.isBoxOpen('workoutSetCategories')) {
      final sets = Hive.box<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      ).values.where((s) => s.isActive && s.exerciseIds.contains(exercise.id));
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

  String _incompleteTagPrefix(String text) {
    final lastComma = text.lastIndexOf(',');
    final segment = lastComma == -1 ? text : text.substring(lastComma + 1);
    return segment.trimLeft();
  }

  List<String> _finishedTags(String text) {
    final lastComma = text.lastIndexOf(',');
    final finishedPart = lastComma == -1 ? '' : text.substring(0, lastComma);
    return finishedPart
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void _syncTagsListFromController() {
    _tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  void _onTagsChanged(String value) {
    _syncTagsListFromController();
    final prefix = _incompleteTagPrefix(value).toLowerCase();
    final finished = _finishedTags(value).toSet();

    final suggestions = prefix.isEmpty
        ? <String>[]
        : (_knownTagsCatalog.toList()..sort())
              .where((tag) => tag.startsWith(prefix) && !finished.contains(tag))
              .take(8)
              .toList();

    setState(() => _tagSuggestions = suggestions);
  }

  void _applyTagSuggestion(String tag) {
    final text = _tagsController.text;
    final lastComma = text.lastIndexOf(',');
    final newText = lastComma == -1
        ? '$tag, '
        : '${text.substring(0, lastComma + 1)} $tag, ';
    _tagsController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    _onTagsChanged(newText);
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
            Icon(_showOptionalFields ? Icons.expand_less : Icons.expand_more),
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
            labelText: 'Tags',
            hintText: 'e.g., gym, legs, barbell, intermediate',
            border: OutlineInputBorder(),
          ),
          onChanged: _onTagsChanged,
        ),
        if (_tagSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _tagSuggestions.map((tag) {
              return ActionChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    color: AppColorPalette.color2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColorPalette.color2.withValues(alpha: 0.12),
                side: BorderSide(
                  color: AppColorPalette.color2.withValues(alpha: 0.35),
                ),
                onPressed: () => _applyTagSuggestion(tag),
              );
            }).toList(),
          ),
        ],
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
    final accent = AppColorPalette.color2;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onPressed,
          style: buttonStyle,
          icon: Icon(icon, size: 18, color: accent),
          label: Text(label, style: TextStyle(color: accent)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent,
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
                border: Border.all(color: AppColorPalette.grey300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageUrl == null || _imageUrl!.isEmpty
                  ? Icon(Icons.image_outlined, size: 36, color: accent)
                  : WorkoutIconWidget(imageUrl: _imageUrl, size: 96),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  action(
                    icon: Icons.photo_library_outlined,
                    label: 'Phone library',
                    onPressed: _isLoading ? null : _pickFromPhoneLibrary,
                  ),
                  const SizedBox(height: 4),
                  action(
                    icon: Icons.fitness_center,
                    label: 'Exercise images',
                    onPressed: _isLoading ? null : _pickFromExerciseLibrary,
                  ),
                  if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    action(
                      icon: Icons.close,
                      label: 'Remove image',
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _imageUrl = null),
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
      showAppSnack(
        context,
        text: 'Phone library is not available on web',
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
      final fileName = 'exercise_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(
        picked.path,
      ).copy('${exerciseDir.path}/$fileName');

      if (!mounted) return;
      setState(() => _imageUrl = saved.path);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
      context,
      text: 'Could not pick image: $e',
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
      final resolved = ExerciseTagSemantics.resolve(_tags);

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
        boxed.category = resolved.category;
        boxed.muscleGroup = resolved.muscleGroup;
        boxed.equipment = resolved.equipment;
        boxed.difficulty = resolved.difficulty;
        boxed.instructions = instructions;
        boxed.modifiedAt = DateTime.now();
        boxed.tags = resolved.tags;
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
          category: resolved.category,
          muscleGroup: resolved.muscleGroup,
          equipment: resolved.equipment,
          difficulty: resolved.difficulty,
          instructions: instructions,
          isCustom: true,
          createdAt: DateTime.now(),
          tags: resolved.tags,
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

      showAppSnack(
        context,
        text: wasUpdate
                ? 'Exercise updated successfully'
                : 'Exercise created successfully',,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        text: 'Error saving exercise: $e',
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
      final resolved = ExerciseTagSemantics.resolve(_tags);

      final duplicate = ExerciseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: copyName,
        description: _descriptionController.text.trim(),
        category: resolved.category,
        muscleGroup: resolved.muscleGroup,
        equipment: resolved.equipment,
        difficulty: resolved.difficulty,
        instructions: _parseInstructions(),
        videoUrl: source.videoUrl,
        imageUrl: _imageUrl ?? source.imageUrl,
        isCustom: true,
        createdAt: DateTime.now(),
        tags: List.from(resolved.tags),
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

      showAppSnack(
        context,
        text: 'Exercise duplicated — editing copy',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnack(
        context,
        text: 'Error duplicating exercise: $e',
      );
    }
  }
}

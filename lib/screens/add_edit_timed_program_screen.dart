// lib/screens/add_edit_timed_program_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class AddEditTimedProgramScreen extends StatefulWidget {
  final TimedWorkoutModel? program;

  const AddEditTimedProgramScreen({super.key, this.program});

  @override
  State<AddEditTimedProgramScreen> createState() =>
      _AddEditTimedProgramScreenState();
}

class _AddEditTimedProgramScreenState extends State<AddEditTimedProgramScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<_ProgramStepDraft> _steps = [];
  bool _subscribeOnSave = true;
  bool _saving = false;

  bool get _isEditing => widget.program != null;

  bool get _canSave {
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasExercise = _steps.any((s) => s.exerciseId != null);
    return hasName && hasExercise;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    final program = widget.program;
    if (program != null) {
      _nameController.text = program.name;
      _subscribeOnSave = program.isSubscribed;
      for (final item in program.workoutOrder) {
        _steps.add(
          _ProgramStepDraft(
            exerciseId: item.workoutId,
            seconds: item.time,
          ),
        );
      }
    } else {
      _steps.add(_ProgramStepDraft(seconds: 30));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<ExerciseModel> get _exercises {
    if (!Hive.isBoxOpen('exercises')) return [];
    final list = Hive.box<ExerciseModel>('exercises').values
        .where((e) => !e.isArchived)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<ExerciseModel> _createExerciseOnSpot(String name) async {
    final trimmed = name.trim();
    final box = await Hive.openBox<ExerciseModel>('exercises');
    for (final existing in box.values) {
      if (existing.name.toLowerCase().trim() == trimmed.toLowerCase()) {
        return existing;
      }
    }

    final now = DateTime.now();
    final exercise = ExerciseModel(
      id: 'custom_exercise_${now.millisecondsSinceEpoch}',
      name: trimmed,
      description: '',
      category: 'other',
      muscleGroup: 'other',
      equipment: 'none',
      difficulty: 'beginner',
      instructions: const [],
      isCustom: true,
      createdAt: now,
      tags: const ['custom', 'program'],
      measurementUnit: 'seconds',
    );
    await box.put(exercise.id, exercise);
    return exercise;
  }

  Future<void> _onExercisePicked(int index, _ExercisePick pick) async {
    if (pick.exercise != null) {
      setState(() => _steps[index].exerciseId = pick.exercise!.id);
      return;
    }
    final name = pick.createName?.trim() ?? '';
    if (name.isEmpty) return;
    try {
      final created = await _createExerciseOnSpot(name);
      if (!mounted) return;
      setState(() => _steps[index].exerciseId = created.id);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, text: 'Could not create exercise: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_steps.isEmpty || _steps.every((s) => s.exerciseId == null)) {
      showAppSnack(
        context,
        text: 'Add at least one exercise',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final box = await Hive.openBox<TimedWorkoutModel>('timedWorkouts');
      final order = _steps
          .where((s) => s.exerciseId != null && s.seconds > 0)
          .map(
            (s) => TimedWorkoutItem(
              workoutId: s.exerciseId!,
              time: s.seconds,
              useTimed: true,
            ),
          )
          .toList();

      if (_isEditing) {
        final program = widget.program!;
        program.name = _nameController.text.trim();
        program.workoutOrder = order;
        program.modifiedAt = DateTime.now();
        program.isSubscribed = _subscribeOnSave;
        await program.save();
      } else {
        final program = TimedWorkoutModel(
          id: 'program_custom_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          workoutOrder: order,
          createdAt: DateTime.now(),
          isCustom: true,
          isSubscribed: _subscribeOnSave,
        );
        await box.put(program.id, program);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        text: 'Could not save program: $e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _exercises;
    final accent = AppColorPalette.color2;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Program' : 'Create Program'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Program name*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name required'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OnOffToggle(
                    value: _subscribeOnSave,
                    activeColor: accent,
                    size: SettingsRectChipSize.compact,
                    onChanged: (v) => setState(() => _subscribeOnSave = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 88,
                            child: TextFormField(
                              initialValue: step.seconds.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'Sec',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (v) {
                                step.seconds =
                                    int.tryParse(v) ?? step.seconds;
                              },
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n <= 0) return '';
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _steps.length <= 1
                                ? null
                                : () => setState(() => _steps.removeAt(index)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ExerciseAutocompleteField(
                        key: ValueKey('step-exercise-$index'),
                        exercises: exercises,
                        selectedId: step.exerciseId,
                        accent: accent,
                        onPicked: (pick) => _onExercisePicked(index, pick),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => setState(
                () => _steps.add(_ProgramStepDraft(seconds: 30)),
              ),
              icon: Icon(Icons.add, color: accent),
              label: Text('Add step', style: TextStyle(color: accent)),
            ),
            const SizedBox(height: 24),
            if (_isEditing && widget.program!.isCustom)
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete program?'),
                      content: Text('Delete "${widget.program!.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'Delete',
                            style: TextStyle(color: AppColorPalette.color2),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await widget.program!.delete();
                    if (mounted) Navigator.pop(context, true);
                  }
                },
                child: Text(
                  'Delete program',
                  style: TextStyle(color: AppColorPalette.color2),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _canSave
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(
                      _saving ? 'Saving…' : 'Save Program',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProgramStepDraft {
  String? exerciseId;
  int seconds;

  _ProgramStepDraft({this.exerciseId, required this.seconds});
}

class _ExercisePick {
  final ExerciseModel? exercise;
  final String? createName;

  const _ExercisePick.existing(this.exercise) : createName = null;
  const _ExercisePick.create(this.createName) : exercise = null;

  bool get isCreate => createName != null;

  String get fieldText => exercise?.name ?? createName?.trim() ?? '';

  String get listLabel =>
      isCreate ? 'Create "${createName!.trim()}"' : (exercise?.name ?? '');
}

class _ExerciseAutocompleteField extends StatelessWidget {
  final List<ExerciseModel> exercises;
  final String? selectedId;
  final Color accent;
  final ValueChanged<_ExercisePick> onPicked;

  const _ExerciseAutocompleteField({
    super.key,
    required this.exercises,
    required this.selectedId,
    required this.accent,
    required this.onPicked,
  });

  String get _selectedName {
    if (selectedId == null) return '';
    for (final e in exercises) {
      if (e.id == selectedId) return e.name;
    }
    return '';
  }

  Iterable<_ExercisePick> _optionsFor(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final matches = query.isEmpty
        ? exercises
        : exercises
            .where((e) => e.name.toLowerCase().contains(query))
            .toList(growable: false);

    final picks = <_ExercisePick>[
      for (final e in matches.take(40)) _ExercisePick.existing(e),
    ];

    if (query.isNotEmpty) {
      final hasExact = exercises.any(
        (e) => e.name.toLowerCase().trim() == query,
      );
      if (!hasExact) {
        picks.add(_ExercisePick.create(rawQuery.trim()));
      }
    }
    return picks;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_ExercisePick>(
      initialValue: TextEditingValue(text: _selectedName),
      displayStringForOption: (pick) => pick.fieldText,
      optionsBuilder: (value) => _optionsFor(value.text),
      onSelected: onPicked,
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final pick = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      pick.isCreate ? Icons.add_circle_outline : Icons.fitness_center,
                      color: pick.isCreate ? accent : null,
                      size: 20,
                    ),
                    title: Text(
                      pick.listLabel,
                      style: TextStyle(
                        fontWeight:
                            pick.isCreate ? FontWeight.w600 : FontWeight.w400,
                        color: pick.isCreate ? accent : null,
                      ),
                    ),
                    onTap: () => onSelected(pick),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Exercise',
            hintText: 'Type to search or create',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          validator: (_) =>
              selectedId == null ? 'Pick or create an exercise' : null,
          onFieldSubmitted: (value) {
            final options = _optionsFor(value).toList();
            if (options.isEmpty) return;
            // Prefer exact match, else the create row, else first filter hit.
            final needle = value.trim().toLowerCase();
            _ExercisePick? exact;
            _ExercisePick? create;
            for (final pick in options) {
              if (pick.exercise != null &&
                  pick.exercise!.name.toLowerCase().trim() == needle) {
                exact = pick;
              }
              if (pick.isCreate) create = pick;
            }
            onPicked(exact ?? create ?? options.first);
            onFieldSubmitted();
          },
        );
      },
    );
  }
}

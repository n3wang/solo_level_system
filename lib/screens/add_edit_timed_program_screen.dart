// lib/screens/add_edit_timed_program_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';

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
    final list = Hive.box<ExerciseModel>('exercises').values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_steps.isEmpty || _steps.every((s) => s.exerciseId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save program: $e')),
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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Program name*',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 12),
            OnOffToggleListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Subscribe', style: TextStyle(color: accent)),
              subtitle: const Text('Show this program on the Programs tab'),
              value: _subscribeOnSave,
              activeColor: accent,
              onChanged: (v) => setState(() => _subscribeOnSave = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Steps (exercise + seconds)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
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
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _steps.length <= 1
                                ? null
                                : () => setState(() => _steps.removeAt(index)),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: step.exerciseId != null &&
                                exercises.any((e) => e.id == step.exerciseId)
                            ? step.exerciseId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Exercise',
                          border: OutlineInputBorder(),
                        ),
                        items: exercises
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) =>
                            setState(() => step.exerciseId = id),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: step.seconds.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seconds',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          step.seconds = int.tryParse(v) ?? step.seconds;
                        },
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter seconds';
                          return null;
                        },
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

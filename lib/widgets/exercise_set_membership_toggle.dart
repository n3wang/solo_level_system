// lib/widgets/exercise_set_membership_toggle.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';

/// Numbered 1–5 set membership toggles for an exercise.
///
/// When [exerciseId] is set and [persistImmediately] is true, taps call
/// [WorkoutSetCategoryModel.addExercise] / [removeExercise] right away.
/// Otherwise selection is controlled via [selectedSetIds] + [onChanged].
class ExerciseSetMembershipToggle extends StatelessWidget {
  final String? exerciseId;
  final Set<String>? selectedSetIds;
  final ValueChanged<Set<String>>? onChanged;
  final bool persistImmediately;
  final bool showSelectedNames;

  const ExerciseSetMembershipToggle({
    super.key,
    this.exerciseId,
    this.selectedSetIds,
    this.onChanged,
    this.persistImmediately = false,
    this.showSelectedNames = true,
  });

  List<WorkoutSetCategoryModel> _activeSets() {
    if (!Hive.isBoxOpen('workoutSetCategories')) return [];
    final sets = Hive.box<WorkoutSetCategoryModel>(
      'workoutSetCategories',
    ).values.where((s) => s.isActive).toList();
    sets.sort((a, b) => a.position.compareTo(b.position));
    return sets;
  }

  Set<String> _membershipFor(
    String exerciseId,
    List<WorkoutSetCategoryModel> sets,
  ) {
    return sets
        .where((s) => s.exerciseIds.contains(exerciseId))
        .map((s) => s.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('workoutSetCategories')) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutSetCategoryModel>(
        'workoutSetCategories',
      ).listenable(),
      builder: (context, Box<WorkoutSetCategoryModel> box, _) {
        final sets = _activeSets();
        if (sets.isEmpty) return const SizedBox.shrink();

        final selected = persistImmediately && exerciseId != null
            ? _membershipFor(exerciseId!, sets)
            : (selectedSetIds ?? <String>{});

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: AppColorPalette.textSecondary,
                ),
                const SizedBox(width: AppUiSizes.sm),
                Text(
                  'Sets',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorPalette.grey700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppUiSizes.md),
            Wrap(
              spacing: AppUiSizes.sm,
              runSpacing: AppUiSizes.sm,
              children: sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                final isSelected = selected.contains(set.id);
                final setColor = AppColorPalette.colorForSetPosition(
                  set.position,
                );

                return GestureDetector(
                  onTap: () => _onToggle(set, isSelected, selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? setColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppUiSizes.buttonRadius,
                      ),
                      border: Border.all(
                        color: isSelected ? setColor : AppColorPalette.grey800,
                        width: 1,
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
            if (showSelectedNames && selected.isNotEmpty) ...[
              const SizedBox(height: AppUiSizes.sm),
              Text(
                selected
                    .map((id) {
                      final match = sets.where((s) => s.id == id);
                      return match.isEmpty ? null : match.first.name;
                    })
                    .whereType<String>()
                    .join(', '),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColorPalette.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _onToggle(
    WorkoutSetCategoryModel set,
    bool isSelected,
    Set<String> current,
  ) {
    if (persistImmediately && exerciseId != null) {
      if (isSelected) {
        set.removeExercise(exerciseId!);
      } else {
        set.addExercise(exerciseId!);
      }
      return;
    }

    final next = Set<String>.from(current);
    if (isSelected) {
      next.remove(set.id);
    } else {
      next.add(set.id);
    }
    onChanged?.call(next);
  }
}

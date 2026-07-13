// lib/screens/programs_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/screens/program_running_screen.dart';
import 'package:solo_level_system/screens/manage_programs_screen.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  _ProgramsScreenState createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  late PageController _pageController;
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<TimedWorkoutModel> _subscribedPrograms(Box<TimedWorkoutModel> box) {
    final programs = box.values.where((p) => p.isSubscribed).toList()
      ..sort((a, b) {
        if (a.isBookmarked && !b.isBookmarked) return -1;
        if (!a.isBookmarked && b.isBookmarked) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return programs;
  }

  void _selectProgram(int index, List<TimedWorkoutModel> programs) {
    if (index < 0 || index >= programs.length) return;
    setState(() {
      _selectedProgramId = programs[index].id;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<TimedWorkoutModel>('timedWorkouts').listenable(),
        builder: (context, Box<TimedWorkoutModel> box, _) {
          final subscribed = _subscribedPrograms(box);

          if (subscribed.isEmpty) {
            return EmptyState(
              icon: Icons.fitness_center,
              title: 'No Subscribed Programs',
              subtitle: 'Open Manage to subscribe or create a program',
              action: PrimaryActionButton(
                text: 'Manage',
                icon: Icons.tune,
                onPressed: _openManage,
              ),
            );
          }

          // Keep selection valid
          final selectedIndex = subscribed.indexWhere(
            (p) => p.id == _selectedProgramId,
          );
          final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
          if (_selectedProgramId != subscribed[safeIndex].id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _selectedProgramId = subscribed[safeIndex].id;
              });
            });
          }

          return Column(
            children: [
              _buildSubscriptionChips(subscribed, safeIndex),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedProgramId = subscribed[index].id;
                    });
                  },
                  itemCount: subscribed.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildProgramCard(subscribed[index]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: CustomFloatingActionButton(
        heroTag: 'programs_manage',
        label: 'Manage',
        icon: Icons.tune,
        onPressed: _openManage,
      ),
    );
  }

  Future<void> _openManage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageProgramsScreen()),
    );
    if (mounted) setState(() {});
  }

  /// Mini cards styled like Sets filters (1, 2, 3…).
  Widget _buildSubscriptionChips(
    List<TimedWorkoutModel> programs,
    int selectedIndex,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.5)
            : AppColorPalette.backgroundSurface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: AppColorPalette.grey300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < programs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _ProgramIndexChip(
                label: '${i + 1}',
                isSelected: i == selectedIndex,
                onTap: () => _selectProgram(i, programs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard(TimedWorkoutModel program) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
      builder: (context, Box<ExerciseModel> exercisesBox, _) {
        final exerciseImages = _getExerciseImages(program, exercisesBox);

        return GestureDetector(
          onTap: () => _startProgram(program),
          behavior: HitTestBehavior.opaque,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColorPalette.grey300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final isCompleted = index < program.timesPerformed;
                        return Container(
                          width: 20,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColorPalette.color2
                                : AppColorPalette.grey300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => program.toggleBookmark(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            program.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: program.isBookmarked
                                ? AppColorPalette.color2
                                : AppColorPalette.grey400,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    program.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: AppColorPalette.color2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${program.formattedDuration}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColorPalette.color2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: AppColorPalette.color2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Performed: ${program.timesPerformed}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColorPalette.color2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildExerciseImageGrid(exerciseImages),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startProgram(TimedWorkoutModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramRunningScreen(program: program),
      ),
    );
  }

  /// Fixed 4×4 slots — no scrolling; empty cells when fewer than 16 images.
  Widget _buildExerciseImageGrid(List<String?> exerciseImages) {
    const cols = 4;
    const rows = 4;
    const spacing = 8.0;

    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: spacing),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) const SizedBox(width: spacing),
                  Expanded(
                    child: _buildGridCell(
                      exerciseImages.length > row * cols + col
                          ? exerciseImages[row * cols + col]
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGridCell(String? imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColorPalette.white,
        borderRadius: BorderRadius.circular(8),
        border: imageUrl == null
            ? Border.all(color: AppColorPalette.grey200)
            : null,
      ),
      child: imageUrl == null
          ? const SizedBox.expand()
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WorkoutIconWidget(
                imageUrl: imageUrl,
                size: double.infinity,
                backgroundColor: AppColorPalette.white,
                placeholder: Icon(
                  Icons.fitness_center,
                  color: AppColorPalette.textSecondary,
                  size: 24,
                ),
              ),
            ),
    );
  }

  List<String?> _getExerciseImages(
    TimedWorkoutModel program,
    Box<ExerciseModel> exercisesBox,
  ) {
    final images = <String?>[];
    for (final item in program.workoutOrder) {
      if (images.length >= 16) break;
      ExerciseModel? exercise = exercisesBox.get(item.workoutId);
      exercise ??= exercisesBox.values.cast<ExerciseModel?>().firstWhere(
            (ex) => ex?.id == item.workoutId,
            orElse: () => null,
          );
      if (exercise == null) continue;
      if (exercise.name.toLowerCase() == 'break' ||
          exercise.name.toLowerCase() == 'rest') {
        continue;
      }
      if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) {
        images.add(exercise.imageUrl);
      }
    }
    return images;
  }
}

class _ProgramIndexChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProgramIndexChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColorPalette.grey800;
    final unselectedTextColor =
        isDark ? AppColorPalette.grey300 : AppColorPalette.grey800;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36 * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          border: Border.all(
            color: isSelected ? selectedColor : AppColorPalette.grey400,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColorPalette.white : unselectedTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// lib/screens/programs_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  _ProgramsScreenState createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  late PageController _pageController;
  int _currentPage = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: Hive.box<TimedWorkoutModel>('timedWorkouts').listenable(),
        builder: (context, Box<TimedWorkoutModel> box, _) {
          final allPrograms = box.values.toList()
            ..sort((a, b) {
              // Bookmarked programs appear first
              if (a.isBookmarked && !b.isBookmarked) return -1;
              if (!a.isBookmarked && b.isBookmarked) return 1;
              // Then sort by name
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          if (allPrograms.isEmpty) {
            return EmptyState(
              icon: Icons.fitness_center,
              title: 'No Programs',
              subtitle: 'Create your first program to get started',
              action: PrimaryActionButton(
                text: 'Add Program',
                icon: Icons.add,
                onPressed: () {
                  // TODO: Navigate to add program screen
                },
              ),
            );
          }

          // Calculate total completions across all programs
          final totalCompletions = allPrograms.fold<int>(
            0,
            (sum, program) => sum + program.timesPerformed,
          );

          return Column(
            children: [
              // Top completion indicators (10 rectangles for general completions)
              _buildGeneralCompletionIndicators(totalCompletions),
              SizedBox(height: 16),
              // Swipeable program cards
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: allPrograms.length,
                  itemBuilder: (context, index) {
                    final program = allPrograms[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _buildProgramCard(program),
                    );
                  },
                ),
              ),
              // Page indicator dots
              if (allPrograms.length > 1)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      allPrograms.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : AppColorPalette.grey300,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: CustomFloatingActionButton(
        heroTag: "programs_add_program",
        label: 'Add Program',
        icon: Icons.add,
        onPressed: () {
          // TODO: Navigate to add program screen
        },
      ),
    );
  }

  Widget _buildGeneralCompletionIndicators(int totalCompletions) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(10, (index) {
          final isCompleted = index < totalCompletions;
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2),
              height: 8,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColorPalette.success
                    : AppColorPalette.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgramCard(TimedWorkoutModel program) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
      builder: (context, Box<ExerciseModel> exercisesBox, _) {
        // Get exercise images (excluding breaks)
        final exerciseImages = _getExerciseImages(program, exercisesBox);

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with completion indicators and bookmark
                Row(
                  children: [
                    // 5 completion indicators for this specific program
                    ...List.generate(5, (index) {
                      final isCompleted = index < program.timesPerformed;
                      return Container(
                        width: 20,
                        height: 8,
                        margin: EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColorPalette.success
                              : AppColorPalette.grey300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                    Spacer(),
                    // Bookmark icon
                    GestureDetector(
                      onTap: () {
                        program.toggleBookmark();
                      },
                      child: Icon(
                        program.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: program.isBookmarked
                            ? AppColorPalette.warning
                            : AppColorPalette.grey400,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Program title
                Text(
                  program.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                // Duration and times performed
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: AppColorPalette.grey600),
                    SizedBox(width: 4),
                    Text(
                      'Duration: ${program.formattedDuration}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColorPalette.grey600,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.repeat, size: 16, color: AppColorPalette.grey600),
                    SizedBox(width: 4),
                    Text(
                      'Performed: ${program.timesPerformed}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColorPalette.grey600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Exercise grid (first 12 exercises, excluding breaks)
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: exerciseImages.length > 12 ? 12 : exerciseImages.length,
                    itemBuilder: (context, index) {
                      final imageUrl = exerciseImages[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColorPalette.backgroundDarkSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: WorkoutIconWidget(
                            imageUrl: imageUrl,
                            size: double.infinity,
                            backgroundColor: AppColorPalette.backgroundDarkSurface,
                            placeholder: Icon(
                              Icons.fitness_center,
                              color: AppColorPalette.grey400,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                // Start button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Start program workout
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Start Program',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String?> _getExerciseImages(
    TimedWorkoutModel program,
    Box<ExerciseModel> exercisesBox,
  ) {
    final images = <String?>[];
    for (final item in program.workoutOrder) {
      final exercise = exercisesBox.get(item.workoutId);
      if (exercise != null &&
          exercise.name.toLowerCase() != 'break' &&
          exercise.name.toLowerCase() != 'rest') {
        if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) {
          images.add(exercise.imageUrl);
        }
      }
    }
    return images;
  }
}

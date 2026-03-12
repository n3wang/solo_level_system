// lib/screens/active_workout_session_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_model.dart';
import 'package:solo_level_system/models/workout_routine_model.dart';
import 'package:solo_level_system/screens/add_edit_routine_screen.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/utils/workout_service.dart';
import 'package:solo_level_system/utils/workout_motivation_service.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

class ActiveWorkoutSessionScreen extends StatefulWidget {
  final WorkoutSessionModel session;
  final List<ExerciseModel> exercises;
  final WorkoutRoutineModel? routine;

  const ActiveWorkoutSessionScreen({
    super.key,
    required this.session,
    required this.exercises,
    this.routine,
  });

  @override
  _ActiveWorkoutSessionScreenState createState() =>
      _ActiveWorkoutSessionScreenState();
}

class _ActiveWorkoutSessionScreenState extends State<ActiveWorkoutSessionScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  Duration _workoutDuration = Duration.zero;
  int _currentExerciseIndex = 0;
  bool _isPaused = false;
  bool _isResting = false;
  Timer? _restTimer;
  Duration _restDuration = Duration.zero;
  WorkoutQuoteVm? _motivationQuote;

  late TabController _tabController;
  final Map<String, List<WorkoutSetModel>> _exerciseSets = {};
  final Map<String, int> _completedSets = {};

  // ignore: unused_field
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.exercises.length,
      vsync: this,
    );
    _initializeWorkout();
    _motivationQuote = WorkoutMotivationService.randomAcquiredQuote();
    _startTimer();
  }

  Future<void> _initializeWorkout() async {
    // Ensure exercises box is open and refresh exercises to get latest last workout data
    if (!Hive.isBoxOpen('exercises')) {
      await Hive.openBox<ExerciseModel>('exercises');
    }
    final exercisesBox = Hive.box<ExerciseModel>('exercises');

    // Initialize sets for each exercise
    for (final exercise in widget.exercises) {
      // Refresh exercise from Hive to ensure we have the latest last workout data
      final refreshedExercise = exercisesBox.get(exercise.id) ?? exercise;

      // Priority: 1. Last workout data, 2. Routine sets, 3. Defaults
      final lastWorkout = WorkoutService.getLastWorkoutData(refreshedExercise);

      if (lastWorkout != null) {
        // Use last workout data if available (takes priority over routine)
        _exerciseSets[exercise.id] = WorkoutService.createSetsFromLastWorkout(
          exercise: refreshedExercise,
          exerciseId: exercise.id,
        );
      } else if (widget.routine != null &&
          widget.routine!.exerciseSets.containsKey(exercise.id)) {
        // Use routine's predefined sets but reset completion status for new session
        final routineSets = widget.routine!.exerciseSets[exercise.id]!;
        _exerciseSets[exercise.id] = routineSets
            .map(
              (set) => WorkoutSetModel(
                id: set.id,
                exerciseId: set.exerciseId,
                reps: set.reps,
                measurementType: set.measurementType,
                value: set.value,
                restTimeSeconds: set.restTimeSeconds,
                isCompleted: false, // Always start with unchecked boxes
                completedAt: null, // Clear completion time
                notes: set.notes,
              ),
            )
            .toList();
      } else {
        // Create default sets if no last workout data and no routine
        _exerciseSets[exercise.id] = WorkoutService.createSetsFromLastWorkout(
          exercise: refreshedExercise,
          exerciseId: exercise.id,
        );
      }
      _completedSets[exercise.id] = 0;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        setState(() {
          _workoutDuration = _workoutDuration + Duration(seconds: 1);
          if (_workoutDuration.inSeconds % 45 == 0) {
            _motivationQuote = WorkoutMotivationService.randomAcquiredQuote(
              excludeQuote: _motivationQuote?.quote,
              excludeItemId: _motivationQuote?.itemId,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _restTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.session.routineName),
                  Text(
                    _formatDuration(_workoutDuration),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColorPalette.grey300,
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.routine != null)
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: _editRoutine,
                    tooltip: 'Edit Routine',
                  ),
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  onPressed: _togglePause,
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: _showEndWorkoutDialog,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: widget.exercises.map((exercise) {
                  final completedSets = _completedSets[exercise.id] ?? 0;
                  final totalSets = _exerciseSets[exercise.id]?.length ?? 0;

                  return Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          exercise.name,
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$completedSets/$totalSets',
                          style: TextStyle(
                            fontSize: 10,
                            color: completedSets == totalSets
                                ? AppColorPalette.success
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            body: Column(
              children: [
                if (_isResting) _buildRestTimer(),
                if (_motivationQuote != null &&
                    _motivationQuote!.quote.trim().isNotEmpty)
                  _buildMotivationQuoteBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: widget.exercises.map((exercise) {
                      return _buildExerciseView(exercise);
                    }).toList(),
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: AppColorPalette.black.withValues(alpha: 0.54),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColorPalette.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving workout...',
                      style: TextStyle(
                        color: AppColorPalette.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      color: AppColorPalette.info.withValues(alpha: 0.1),
      child: Column(
        children: [
          Text(
            'Rest Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColorPalette.info,
            ),
          ),
          Text(
            _formatDuration(_restDuration),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColorPalette.info,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _adjustRestTime(-10),
                child: Text('-10s'),
              ),
              TextButton(
                onPressed: () => _adjustRestTime(-30),
                child: Text('-30s'),
              ),
              TextButton(onPressed: _skipRest, child: Text('Skip')),
              TextButton(
                onPressed: () => _adjustRestTime(30),
                child: Text('+30s'),
              ),
              TextButton(
                onPressed: () => _adjustRestTime(60),
                child: Text('+60s'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationQuoteBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showMotivationQuoteDetails,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.format_quote,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _motivationQuote!.quote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.casino_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMotivationQuoteDetails() async {
    if (_motivationQuote == null) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        WorkoutQuoteVm current = _motivationQuote!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.author,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: current.imageIndex != null && current.imageIndex! > 0
                          ? SpriteImage(
                              sheet: 'motivation_64',
                              index: current.imageIndex! - 1,
                              size: 96,
                            )
                          : Icon(
                              Icons.format_quote,
                              size: 64,
                              color: scheme.primary,
                            ),
                    ),
                    if (current.aboutAuthor.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        current.aboutAuthor,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      current.quote,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final next = WorkoutMotivationService.randomAcquiredQuote(
                              excludeQuote: current.quote,
                              excludeItemId: current.itemId,
                            );
                            if (next == null) return;
                            setState(() {
                              _motivationQuote = next;
                            });
                            setDialogState(() {
                              current = next;
                            });
                          },
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Random'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExerciseView(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id] ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExerciseHeader(exercise),
          SizedBox(height: 24),
          _buildExerciseInstructions(exercise),
          SizedBox(height: 24),
          _buildSetsTable(exercise, sets),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader(ExerciseModel exercise) {
    final isCompleted = _allSetsCompleted(exercise);

    return Card(
      color: isCompleted
          ? AppColorPalette.success.withValues(alpha: 0.1)
          : null, // Light success background when completed
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCompleted
            ? BorderSide(
                color: AppColorPalette.success.withValues(alpha: 0.5),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColorPalette.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RepaintBoundary(
                      child: WorkoutIconWidget(
                        key: ValueKey(
                          'exercise_icon_${exercise.id}_${exercise.imageUrl}',
                        ),
                        imageUrl: exercise.imageUrl,
                        size: 60,
                        backgroundColor: AppColorPalette.white,
                        placeholder: Icon(
                          _getMuscleGroupIcon(exercise.muscleGroup),
                          color: _getMuscleGroupColor(exercise.muscleGroup),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColorPalette.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColorPalette.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColorPalette.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Icon(
                          Icons.check_circle,
                          color: AppColorPalette.success,
                          size: 24,
                        ),
                    ],
                  ),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.equipment}',
                    style: TextStyle(
                      color: AppColorPalette.grey600,
                      fontSize: 14,
                    ),
                  ),
                  if (exercise.personalRecord != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'PR: ${exercise.personalRecord}kg',
                      style: TextStyle(
                        color: AppColorPalette.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInstructions(ExerciseModel exercise) {
    if (exercise.instructions.isEmpty) return SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.info_outline, color: AppColorPalette.info),
        title: Text('Instructions'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: exercise.instructions
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColorPalette.info,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color: AppColorPalette.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsTable(ExerciseModel exercise, List<WorkoutSetModel> sets) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Table(
              columnWidths: _getTableColumnWidths(exercise),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppColorPalette.grey100),
                  children: _buildTableHeaders(exercise),
                ),
                ...sets.asMap().entries.map(
                  (entry) => _buildSetRow(exercise, entry.key, entry.value),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addSet(exercise),
                    child: Icon(Icons.add),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resetSetsToDefault(exercise),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorPalette.warning,
                      foregroundColor: AppColorPalette.white,
                    ),
                    child: Icon(Icons.refresh),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _allSetsCompleted(exercise)
                        ? () => _nextExercise()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allSetsCompleted(exercise)
                          ? AppColorPalette.success
                          : null,
                    ),
                    child: Icon(Icons.arrow_forward),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Map<int, TableColumnWidth> _getTableColumnWidths(ExerciseModel exercise) {
    final unit = exercise.measurementUnit;
    if (unit == 'none') {
      // Bodyweight only - no weight/duration column
      return {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1),
      };
    } else if (unit == 'seconds') {
      // Time-based - show duration instead of weight
      return {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1),
      };
    } else {
      // Weight-based (kg or lbs)
      return {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1),
      };
    }
  }

  List<Widget> _buildTableHeaders(ExerciseModel exercise) {
    final unit = exercise.measurementUnit;
    final headers = <Widget>[
      _buildTableHeader('Set'),
      _buildTableHeader('Reps'),
    ];

    if (unit == 'seconds') {
      headers.add(_buildTableHeader('Duration'));
    } else if (unit == 'none') {
      // No additional column for bodyweight exercises
    } else {
      // Weight-based (kg or lbs)
      final unitLabel = unit == 'lbs' ? 'Weight (lbs)' : 'Weight (kg)';
      headers.add(_buildTableHeader(unitLabel));
    }

    headers.add(_buildTableHeader('✓'));
    return headers;
  }

  TableRow _buildSetRow(
    ExerciseModel exercise,
    int index,
    WorkoutSetModel set,
  ) {
    final unit = exercise.measurementUnit;
    final cells = <Widget>[
      Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(4),
        child: TextFormField(
          initialValue: set.reps.toString(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {
              set.reps = int.tryParse(value) ?? 0;
            });
          },
        ),
      ),
    ];

    // Add measurement column based on unit type
    if (unit == 'seconds') {
      // Time-based exercise - show duration input
      cells.add(
        Padding(
          padding: EdgeInsets.all(4),
          child: TextFormField(
            initialValue:
                set.duration?.toString() ??
                (set.measurementType == 'seconds' ? '30' : '0'),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'sec',
            ),
            onChanged: (value) {
              setState(() {
                final durationValue = int.tryParse(value);
                if (durationValue != null) {
                  set.updateDuration(durationValue);
                } else {
                  set.value = null;
                }
              });
            },
          ),
        ),
      );
    } else if (unit == 'none') {
      // Bodyweight only - no measurement column
    } else {
      // Weight-based (kg or lbs)
      cells.add(
        Padding(
          padding: EdgeInsets.all(4),
          child: TextFormField(
            initialValue:
                set.value?.toString() ??
                (set.measurementType == 'none' ? '' : '0'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: unit,
            ),
            onChanged: (value) {
              setState(() {
                final weightValue = double.tryParse(value);
                set.updateValue(weightValue, unit);
              });
            },
          ),
        ),
      );
    }

    // Add completion checkbox
    cells.add(
      Padding(
        padding: EdgeInsets.all(8),
        child: Checkbox(
          value: set.isCompleted,
          onChanged: (value) => _toggleSetCompletion(exercise, index),
        ),
      ),
    );

    return TableRow(children: cells);
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColorPalette.white,
        boxShadow: [
          BoxShadow(
            color: AppColorPalette.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Workout Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColorPalette.grey600,
                  ),
                ),
                Text(
                  _formatDuration(_workoutDuration),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          VerticalDivider(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sets Completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColorPalette.grey600,
                  ),
                ),
                Text(
                  '${_getTotalCompletedSets()}/${_getTotalSets()}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          VerticalDivider(),
          Flexible(
            child: ElevatedButton(
              onPressed: _showEndWorkoutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColorPalette.error,
                foregroundColor: AppColorPalette.white,
              ),
              child: Text('Finish'),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleSetCompletion(ExerciseModel exercise, int setIndex) {
    setState(() {
      final sets = _exerciseSets[exercise.id]!;
      final set = sets[setIndex];
      set.isCompleted = !set.isCompleted;

      if (set.isCompleted) {
        set.completedAt = DateTime.now();
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 0) + 1;
        _startRestTimer(set.restTimeSeconds);
      } else {
        set.completedAt = null;
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 1) - 1;
      }
    });
  }

  void _startRestTimer(int restSeconds) {
    if (_isResting) return;

    setState(() {
      _isResting = true;
      _restDuration = Duration(seconds: restSeconds);
    });

    _restTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_restDuration.inSeconds > 0) {
          _restDuration = _restDuration - Duration(seconds: 1);
        } else {
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restDuration = _restDuration + Duration(seconds: seconds);
      if (_restDuration.inSeconds <= 0) {
        _skipRest();
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restDuration = Duration.zero;
    });
  }

  void _addSet(ExerciseModel exercise) {
    setState(() {
      final sets = _exerciseSets[exercise.id]!;
      final unit = exercise.measurementUnit;

      // Determine default values based on unit type
      double? defaultValue;

      if (unit == 'seconds') {
        // Time-based: use duration, default to 30 seconds
        defaultValue = sets.isNotEmpty ? sets.last.value : 30.0;
      } else if (unit == 'none') {
        // Bodyweight: no weight or duration
        defaultValue = null;
      } else {
        // Weight-based: default to 10 (kg or lbs)
        defaultValue = sets.isNotEmpty ? sets.last.value : 10.0;
      }

      sets.add(
        WorkoutSetModel(
          id: '${exercise.id}_set_${sets.length + 1}',
          exerciseId: exercise.id,
          reps: sets.isNotEmpty ? sets.last.reps : 10,
          measurementType: unit,
          value: defaultValue,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
      );
    });
  }

  void _resetSetsToDefault(ExerciseModel exercise) {
    final hasRoutine =
        widget.routine != null &&
        widget.routine!.exerciseSets.containsKey(exercise.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Sets'),
        content: Text(
          hasRoutine
              ? 'This will reset all values for this exercise to the routine\'s original values. Completion status will be preserved. Are you sure?'
              : _getResetMessage(exercise),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performSetReset(exercise);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColorPalette.warning,
            ),
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  String _getResetMessage(ExerciseModel exercise) {
    final unit = exercise.measurementUnit;
    switch (unit) {
      case 'seconds':
        return 'This will reset all values for this exercise to default values (10 reps, 30 seconds). Completion status will be preserved. Are you sure?';
      case 'none':
        return 'This will reset all reps for this exercise to default values (10 reps). Completion status will be preserved. Are you sure?';
      case 'lbs':
        return 'This will reset all values for this exercise to default values (10 reps, 10lbs). Completion status will be preserved. Are you sure?';
      default:
        return 'This will reset all values for this exercise to default values (10 reps, 10kg). Completion status will be preserved. Are you sure?';
    }
  }

  void _performSetReset(ExerciseModel exercise) {
    setState(() {
      final currentSets = _exerciseSets[exercise.id]!;
      final unit = exercise.measurementUnit;

      if (widget.routine != null &&
          widget.routine!.exerciseSets.containsKey(exercise.id)) {
        // Reset to routine's default values
        final routineSets = widget.routine!.exerciseSets[exercise.id]!;

        for (int i = 0; i < currentSets.length; i++) {
          if (i < routineSets.length) {
            // Reset to routine values, but preserve completion status
            final isCompleted = currentSets[i].isCompleted;
            final completedAt = currentSets[i].completedAt;

            currentSets[i].reps = routineSets[i].reps;
            currentSets[i].measurementType = routineSets[i].measurementType;
            currentSets[i].value = routineSets[i].value;
            currentSets[i].restTimeSeconds = routineSets[i].restTimeSeconds;
            currentSets[i].notes = routineSets[i].notes;

            // Preserve completion status
            currentSets[i].isCompleted = isCompleted;
            currentSets[i].completedAt = completedAt;
          } else {
            // For extra sets not in routine, reset to default values
            final isCompleted = currentSets[i].isCompleted;
            final completedAt = currentSets[i].completedAt;

            currentSets[i].reps = 10;
            _setDefaultMeasurement(currentSets[i], unit);
            currentSets[i].restTimeSeconds = 60;

            // Preserve completion status
            currentSets[i].isCompleted = isCompleted;
            currentSets[i].completedAt = completedAt;
          }
        }
      } else {
        // No routine, reset to default values
        for (final set in currentSets) {
          final isCompleted = set.isCompleted;
          final completedAt = set.completedAt;

          set.reps = 10;
          _setDefaultMeasurement(set, unit);
          set.restTimeSeconds = 60;

          // Preserve completion status
          set.isCompleted = isCompleted;
          set.completedAt = completedAt;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sets reset to default values'),
        backgroundColor: AppColorPalette.warning,
      ),
    );
  }

  void _setDefaultMeasurement(WorkoutSetModel set, String unit) {
    switch (unit) {
      case 'seconds':
        set.updateValue(30.0, 'seconds');
        break;
      case 'none':
        set.updateValue(null, 'none');
        break;
      default:
        set.updateValue(10.0, unit);
        break;
    }
  }

  void _editRoutine() async {
    if (widget.routine == null) return;

    // Pause the workout timer while editing
    final wasPaused = _isPaused;
    if (!_isPaused) {
      _togglePause();
    }

    // Navigate to edit routine screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoutineScreen(routine: widget.routine),
      ),
    );

    // Resume workout timer if it was running before
    if (!wasPaused && _isPaused) {
      _togglePause();
    }

    // If routine was updated, refresh the current workout
    if (result == true) {
      _refreshWorkoutFromRoutine();
    }
  }

  void _refreshWorkoutFromRoutine() async {
    if (widget.routine == null) return;

    try {
      // Reload the routine from Hive to get the latest changes
      final routinesBox = await Hive.openBox<WorkoutRoutineModel>(
        'workoutRoutines',
      );
      if (!mounted) return;

      final updatedRoutine = routinesBox.values.firstWhere(
        (r) => r.id == widget.routine!.id,
        orElse: () => widget.routine!,
      );

      // Update the current exercise sets with any changes from the routine
      _exerciseSets.forEach((exerciseId, currentSets) {
        if (updatedRoutine.exerciseSets.containsKey(exerciseId)) {
          final routineSets = updatedRoutine.exerciseSets[exerciseId]!;

          // Update existing sets while preserving current values and completion status
          for (
            int i = 0;
            i < currentSets.length && i < routineSets.length;
            i++
          ) {
            // Keep current reps, weight, and completion status, but update other properties
            currentSets[i].restTimeSeconds = routineSets[i].restTimeSeconds;
            currentSets[i].notes = routineSets[i].notes;
          }

          // Add any new sets from the routine
          if (routineSets.length > currentSets.length) {
            for (int i = currentSets.length; i < routineSets.length; i++) {
              currentSets.add(
                WorkoutSetModel(
                  id: routineSets[i].id,
                  exerciseId: routineSets[i].exerciseId,
                  reps: routineSets[i].reps,
                  measurementType: routineSets[i].measurementType,
                  value: routineSets[i].value,
                  restTimeSeconds: routineSets[i].restTimeSeconds,
                  isCompleted: false,
                  notes: routineSets[i].notes,
                ),
              );
            }
          }
        }
      });

      setState(() {
        // Trigger UI update
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Routine updated! New sets have been added if any.'),
          backgroundColor: AppColorPalette.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating routine: $e'),
          backgroundColor: AppColorPalette.error,
        ),
      );
    }
  }

  void _nextExercise() {
    if (_currentExerciseIndex < widget.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
      _tabController.animateTo(_currentExerciseIndex);
    } else {
      _showEndWorkoutDialog();
    }
  }

  bool _allSetsCompleted(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id] ?? [];
    return sets.isNotEmpty && sets.every((set) => set.isCompleted);
  }

  int _getTotalCompletedSets() {
    return _completedSets.values.fold(0, (sum, count) => sum + count);
  }

  int _getTotalSets() {
    return _exerciseSets.values.fold(0, (sum, sets) => sum + sets.length);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Color _getMuscleGroupColor(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return AppColorPalette.error;
      case 'back':
        return AppColorPalette.info;
      case 'legs':
        return AppColorPalette.success;
      case 'arms':
        return AppColorPalette.warning;
      case 'shoulders':
        return AppColorPalette.primary;
      case 'core':
        return AppColorPalette.color3;
      default:
        return AppColorPalette.grey;
    }
  }

  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Icons.favorite;
      case 'back':
        return Icons.view_agenda;
      case 'legs':
        return Icons.directions_run;
      case 'arms':
        return Icons.fitness_center;
      case 'shoulders':
        return Icons.accessibility;
      case 'core':
        return Icons.center_focus_strong;
      default:
        return Icons.fitness_center;
    }
  }

  Future<bool> _onWillPop() async {
    // Check if all sets are completed
    final allCompleted = widget.exercises.every((ex) => _allSetsCompleted(ex));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Workout?'),
        content: Text('What would you like to do with this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Continue'),
          ),
          if (!allCompleted)
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              style: TextButton.styleFrom(
                foregroundColor: AppColorPalette.error,
              ),
              child: Text('Discard'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text('Save & Exit'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      // Save workout and navigate to summary screen
      _endWorkout(shouldNavigate: true);
      return false; // Don't pop, let _endWorkout handle navigation
    } else if (result == 'discard') {
      // Discard workout without saving
      if (mounted) {
        Navigator.pop(context);
      }
      return true; // Allow pop
    }

    return false; // Don't pop
  }

  void _showEndWorkoutDialog() {
    // Check if all sets are completed
    final allCompleted = widget.exercises.every((ex) => _allSetsCompleted(ex));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Workout'),
        content: Text('What would you like to do with this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          if (!allCompleted)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Discard without saving
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColorPalette.error,
              ),
              child: Text('Discard'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endWorkout();
            },
            child: Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _endWorkout({bool shouldNavigate = true}) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Determine if workout is fully completed based on all sets being done
      final allExercisesCompleted = widget.exercises.every(
        (ex) => _allSetsCompleted(ex),
      );

      // Update session with current sets data
      // Always save the workout, whether fully completed or not
      widget.session.endTime = DateTime.now();
      widget.session.durationMinutes = _workoutDuration.inMinutes;
      widget.session.isCompleted = allExercisesCompleted;
      // Mark all saved workouts as 'completed' (whether fully or partially done)
      // This ensures all workouts are saved and tracked
      widget.session.status = 'completed';
      widget.session.totalSetsCompleted = _getTotalCompletedSets();
      widget.session.completedExerciseIds = widget.exercises
          .where((ex) => _allSetsCompleted(ex))
          .map((ex) => ex.id)
          .toList();

      // Save the current sets data to additionalData
      final setsData = <String, dynamic>{};
      _exerciseSets.forEach((exerciseId, sets) {
        setsData[exerciseId] = sets
            .map(
              (set) => {
                'id': set.id,
                'exerciseId': set.exerciseId,
                'reps': set.reps,
                'measurementType': set.measurementType,
                'value': set.value,
                'restTimeSeconds': set.restTimeSeconds,
                'isCompleted': set.isCompleted,
                'completedAt': set.completedAt?.toIso8601String(),
                'notes': set.notes,
              },
            )
            .toList();
      });
      widget.session.additionalData = Map.from(widget.session.additionalData)
        ..['exerciseSets'] = setsData;

      // Always process workout completion: evaluate PRs, save last workout data, update statistics
      final newPersonalRecords = await WorkoutService.processWorkoutCompletion(
        session: widget.session,
        exerciseSets: _exerciseSets,
        exercises: widget.exercises,
      );

      // Save session
      final sessionsBox = await Hive.openBox<WorkoutSessionModel>(
        'workoutSessions',
      );

      // Save or update session using its ID as the key
      await sessionsBox.put(widget.session.id, widget.session);

      // Update routine completion count if all exercises are completed
      if (allExercisesCompleted && widget.routine != null) {
        final routinesBox = await Hive.openBox<WorkoutRoutineModel>(
          'workoutRoutines',
        );
        final routineIndex = routinesBox.values.toList().indexWhere(
          (r) => r.id == widget.routine!.id,
        );
        if (routineIndex != -1) {
          final routine = routinesBox.getAt(routineIndex)!;
          routine.timesCompleted += 1;
          routine.lastCompletedAt = DateTime.now();
          await routinesBox.putAt(routineIndex, routine);
        }
      }

      // Show feedback for new personal records
      if (newPersonalRecords.isNotEmpty && mounted) {
        final exerciseNames = widget.exercises
            .where((ex) => newPersonalRecords.contains(ex.id))
            .map((ex) => ex.name)
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 New Personal Records: $exerciseNames'),
            backgroundColor: AppColorPalette.success,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Clear loading state before navigation
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (shouldNavigate && mounted) {
        // Pop back to workout list with summary data
        Navigator.of(context).pop({
          'session': widget.session,
          'exercises': widget.exercises,
          'totalSetsCompleted': _getTotalCompletedSets(),
          'totalSets': _getTotalSets(),
          'newPersonalRecords': newPersonalRecords,
        });
      }
    } catch (e) {
      // Clear loading state on error
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (shouldNavigate && mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error Saving Workout'),
            content: Text('Failed to save workout: $e\n\nPlease try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

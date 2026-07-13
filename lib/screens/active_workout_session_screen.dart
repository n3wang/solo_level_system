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
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

class ActiveWorkoutSessionScreen extends StatefulWidget {
  final WorkoutSessionModel session;
  final List<ExerciseModel> exercises;
  final WorkoutRoutineModel? routine;

  /// When true, show one exercise at a time with Skip / Next (no exercise tabs).
  final bool sequentialMode;

  /// Starting exercise index when [sequentialMode] is true (e.g. resume).
  final int initialExerciseIndex;

  const ActiveWorkoutSessionScreen({
    super.key,
    required this.session,
    required this.exercises,
    this.routine,
    this.sequentialMode = false,
    this.initialExerciseIndex = 0,
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

  /// Default rest between sets (seconds). Editable from rest settings.
  int _defaultRestSeconds = 60;

  /// When true, set rows show A, B, C… instead of 1, 2, 3…
  bool _useLetterSetLabels = false;

  late TabController _tabController;
  final Map<String, List<WorkoutSetModel>> _exerciseSets = {};
  final Map<String, int> _completedSets = {};

  /// Selected set index per exercise (only one row selected at a time).
  final Map<String, int> _selectedSetIndex = {};

  /// Bumped per exercise when plan shortcuts change sets/weight so inputs refresh
  /// without wiping other exercises' in-progress edits.
  final Map<String, int> _fieldEpoch = {};

  // ignore: unused_field
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final startIndex = widget.initialExerciseIndex.clamp(
      0,
      widget.exercises.isEmpty ? 0 : widget.exercises.length - 1,
    );
    _currentExerciseIndex = startIndex;
    _tabController = TabController(
      length: widget.exercises.isEmpty ? 1 : widget.exercises.length,
      vsync: this,
      initialIndex: widget.exercises.isEmpty ? 0 : startIndex,
    );
    if (!widget.sequentialMode) {
      _tabController.addListener(_onTabChanged);
    }
    _initializeWorkout();
    _motivationQuote = WorkoutMotivationService.randomAcquiredQuote();
    _startTimer();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _currentExerciseIndex != _tabController.index) {
      setState(() {
        _currentExerciseIndex = _tabController.index;
        if (widget.exercises.isNotEmpty) {
          _selectFirstIncompleteSet(
            widget.exercises[_currentExerciseIndex].id,
          );
        }
      });
    }
  }

  Future<void> _initializeWorkout() async {
    // Ensure exercises box is open and refresh exercises to get latest last workout data
    if (!Hive.isBoxOpen('exercises')) {
      await Hive.openBox<ExerciseModel>('exercises');
    }
    if (!mounted) return;
    final exercisesBox = Hive.box<ExerciseModel>('exercises');

    // Initialize sets for each exercise once; never overwrite session edits.
    for (final exercise in widget.exercises) {
      if (_exerciseSets.containsKey(exercise.id)) continue;

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
      _fieldEpoch[exercise.id] = 0;
      _selectedSetIndex[exercise.id] = 0;
    }

    for (final exercise in widget.exercises) {
      _selectFirstIncompleteSet(exercise.id);
    }

    if (mounted) setState(() {});
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
    if (!widget.sequentialMode) {
      _tabController.removeListener(_onTabChanged);
    }
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
                  GestureDetector(
                    onTap: widget.exercises.length > 1
                        ? _showSessionExercisePicker
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.sequentialMode
                                ? 'Exercise ${_currentExerciseIndex + 1} of ${widget.exercises.length}  ·  ${_formatDuration(_workoutDuration)}'
                                : _formatDuration(_workoutDuration),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColorPalette.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.exercises.length > 1) ...[
                          SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more,
                            size: 16,
                            color: AppColorPalette.onPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.routine != null && !widget.sequentialMode)
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: _editRoutine,
                    tooltip: 'Edit Routine',
                  ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: _showSessionSettingsModal,
                  tooltip: 'Session settings',
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
              bottom: widget.sequentialMode
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(8),
                      child: LinearProgressIndicator(
                        value: widget.exercises.isEmpty
                            ? 0
                            : (_currentExerciseIndex + 1) /
                                  widget.exercises.length,
                        backgroundColor: AppColorPalette.white.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColorPalette.white,
                        ),
                        minHeight: 4,
                      ),
                    )
                  : TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: widget.exercises.map((exercise) {
                        final completedSets = _completedSets[exercise.id] ?? 0;
                        final totalSets =
                            _exerciseSets[exercise.id]?.length ?? 0;

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
                                      ? AppColorPalette.color2
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
                if (widget.sequentialMode && widget.exercises.length > 1)
                  _buildExerciseSwapBar(),
                if (_motivationQuote != null &&
                    _motivationQuote!.quote.trim().isNotEmpty)
                  _buildMotivationQuoteBanner(),
                Expanded(
                  child: widget.sequentialMode
                      ? (widget.exercises.isEmpty
                            ? const Center(child: Text('No exercises'))
                            : IndexedStack(
                                index: _currentExerciseIndex.clamp(
                                  0,
                                  widget.exercises.length - 1,
                                ),
                                sizing: StackFit.expand,
                                children: [
                                  for (final exercise in widget.exercises)
                                    KeyedSubtree(
                                      key: ValueKey('seq_keep_${exercise.id}'),
                                      child: _buildExerciseView(exercise),
                                    ),
                                ],
                              ))
                      : TabBarView(
                          controller: _tabController,
                          children: widget.exercises.map((exercise) {
                            return _buildExerciseView(exercise);
                          }).toList(),
                        ),
                ),
                if (widget.sequentialMode && !_isResting)
                  _buildSequentialNavControls(),
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

  Widget _buildCompactRestBar() {
    final radius = AppUiSizes.buttonRadius;
    final accent = AppColorPalette.color2;

    return Row(
      children: [
        Icon(Icons.hourglass_top, color: accent, size: 18),
        const SizedBox(width: 6),
        Text(
          'REST',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: accent,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_restDuration),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: _skipRest,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: () => _adjustRestTime(60),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppColorPalette.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: const Text('+60s'),
          ),
        ),
        IconButton(
          tooltip: 'Rest & set settings',
          onPressed: _showSessionSettingsModal,
          icon: Icon(Icons.settings, color: accent, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ],
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
    final canSwitch = widget.exercises.length > 1;

    return Card(
      color: isCompleted
          ? AppColorPalette.color2.withValues(alpha: 0.1)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCompleted
            ? BorderSide(
                color: AppColorPalette.color2.withValues(alpha: 0.5),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: canSwitch ? _showSessionExercisePicker : null,
        borderRadius: BorderRadius.circular(12),
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
                          color: AppColorPalette.color2,
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
                            color: AppColorPalette.color2,
                            size: 24,
                          ),
                      ],
                    ),
                    Text(
                      '${exercise.muscleGroup} • ${exercise.equipment}',
                      style: TextStyle(
                        color: AppColorPalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (canSwitch) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 14,
                            color: AppColorPalette.color2,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tap to switch exercise',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColorPalette.color2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (exercise.personalRecord != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'PR: ${exercise.personalRecord}kg',
                        style: TextStyle(
                          color: AppColorPalette.grey800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canSwitch)
                Icon(
                  Icons.expand_more,
                  color: AppColorPalette.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseInstructions(ExerciseModel exercise) {
    if (exercise.instructions.isEmpty) return SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.info_outline, color: AppColorPalette.color2),
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
                              color: AppColorPalette.color2,
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
    _ensureValidSelection(exercise.id);

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
            SizedBox(height: 12),
            _buildSetTableHeader(exercise),
            SizedBox(height: 4),
            ...sets.asMap().entries.map(
              (entry) => _buildSelectableSetRow(
                exercise,
                entry.key,
                entry.value,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addSet(exercise, bumpVersion: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorPalette.color2,
                  foregroundColor: AppColorPalette.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
                  ),
                ),
                icon: Icon(Icons.add),
                label: Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetTableHeader(ExerciseModel exercise) {
    final unit = exercise.measurementUnit;
    final measureLabel = unit == 'seconds'
        ? 'Duration'
        : unit == 'none'
        ? null
        : (unit == 'lbs' ? 'Weight (lbs)' : 'Weight (kg)');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'Set',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColorPalette.grey700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Reps',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColorPalette.grey700,
              ),
            ),
          ),
          if (measureLabel != null)
            Expanded(
              child: Text(
                measureLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColorPalette.grey700,
                ),
              ),
            ),
          SizedBox(
            width: 40,
            child: Text(
              '✓',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColorPalette.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableSetRow(
    ExerciseModel exercise,
    int index,
    WorkoutSetModel set,
  ) {
    final unit = exercise.measurementUnit;
    final epoch = _fieldEpoch[exercise.id] ?? 0;
    final isSelected = _selectedSetIndex[exercise.id] == index;
    final accent = AppColorPalette.color3;
    final radius = AppUiSizes.buttonRadius;

    // Side strips instead of uneven BoxDecoration borders (Flutter can't paint
    // non-uniform borders + borderRadius, which blanked out the selected row).
    Widget sideRail() => Container(
      width: 3,
      decoration: BoxDecoration(
        color: isSelected ? accent : AppColorPalette.grey300,
        borderRadius: BorderRadius.circular(1),
      ),
    );

    final fields = Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            _setLabelForIndex(index),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? accent : AppColorPalette.grey800,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TextFormField(
              key: ValueKey('${set.id}_reps_$epoch'),
              initialValue: set.reps.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
                isDense: true,
                filled: true,
                fillColor: AppColorPalette.white,
              ),
              onTap: () => _selectSet(exercise.id, index),
              onChanged: (value) {
                set.reps = int.tryParse(value) ?? 0;
              },
            ),
          ),
        ),
        if (unit == 'seconds')
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextFormField(
                key: ValueKey('${set.id}_dur_$epoch'),
                initialValue:
                    set.duration?.toString() ??
                    (set.measurementType == 'seconds' ? '30' : '0'),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  isDense: true,
                  hintText: 'sec',
                  filled: true,
                  fillColor: AppColorPalette.white,
                ),
                onTap: () => _selectSet(exercise.id, index),
                onChanged: (value) {
                  final durationValue = int.tryParse(value);
                  set.value = durationValue?.toDouble();
                  set.measurementType = 'seconds';
                },
              ),
            ),
          )
        else if (unit != 'none')
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextFormField(
                key: ValueKey('${set.id}_wt_$epoch'),
                initialValue: set.value == null
                    ? '0'
                    : _formatWeightInput(set.value!),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  isDense: true,
                  hintText: unit,
                  filled: true,
                  fillColor: AppColorPalette.white,
                ),
                onTap: () => _selectSet(exercise.id, index),
                onChanged: (value) {
                  set.value = double.tryParse(value);
                  set.measurementType = unit;
                },
              ),
            ),
          ),
        SizedBox(
          width: 40,
          child: Checkbox(
            value: set.isCompleted,
            activeColor: accent,
            onChanged: (value) {
              _toggleSetCompletion(exercise, index);
            },
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColorPalette.white,
        borderRadius: BorderRadius.circular(radius),
        elevation: 0,
        child: InkWell(
          onTap: () => _selectSet(exercise.id, index),
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColorPalette.grey300, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sideRail(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: fields,
                    ),
                  ),
                  sideRail(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatWeightInput(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _isResting
            ? AppColorPalette.color2.withValues(alpha: 0.08)
            : AppColorPalette.white,
        boxShadow: [
          BoxShadow(
            color: AppColorPalette.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: _isResting
            ? _buildCompactRestBar()
            : _buildPrimarySessionAction(),
      ),
    );
  }

  Widget _buildPrimarySessionAction() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
    );

    ButtonStyle styleFor(Color bg) => ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: AppColorPalette.white,
      minimumSize: const Size.fromHeight(48),
      elevation: 0,
      shape: shape,
    );

    if (widget.exercises.isEmpty) {
      return ElevatedButton(
        onPressed: _showEndWorkoutDialog,
        style: styleFor(AppColorPalette.color2),
        child: const Text('Finish'),
      );
    }

    final exercise = widget.exercises[_currentExerciseIndex.clamp(
      0,
      widget.exercises.length - 1,
    )];
    final exerciseDone = _allSetsCompleted(exercise);
    final workoutDone = widget.exercises.every(_allSetsCompleted);

    if (workoutDone) {
      return ElevatedButton(
        onPressed: () => _endWorkout(),
        style: styleFor(AppColorPalette.color2),
        child: const Text('Finish Workout'),
      );
    }

    if (exerciseDone) {
      return ElevatedButton(
        onPressed: _goToNextIncompleteExercise,
        style: styleFor(AppColorPalette.color2),
        child: const Text('Next Exercise'),
      );
    }

    return ElevatedButton(
      onPressed: () => _completeSelectedSet(exercise),
      style: styleFor(AppColorPalette.color3),
      child: const Text('Set Complete'),
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleSetCompletion(ExerciseModel exercise, int setIndex) {
    var startRest = false;
    var restSeconds = 60;
    setState(() {
      final sets = _exerciseSets[exercise.id]!;
      final set = sets[setIndex];
      set.isCompleted = !set.isCompleted;

      if (set.isCompleted) {
        set.completedAt = DateTime.now();
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 0) + 1;
        startRest = true;
        restSeconds = _defaultRestSeconds;
        _selectFirstIncompleteSet(exercise.id);
      } else {
        set.completedAt = null;
        _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 1) - 1;
        _selectedSetIndex[exercise.id] = setIndex;
      }
    });
    if (startRest) _startRestTimer(restSeconds);
  }

  void _completeSelectedSet(ExerciseModel exercise) {
    final sets = _exerciseSets[exercise.id];
    if (sets == null || sets.isEmpty) return;

    _ensureValidSelection(exercise.id);
    var idx = _selectedSetIndex[exercise.id] ?? 0;
    if (idx < 0 || idx >= sets.length || sets[idx].isCompleted) {
      idx = _firstIncompleteSetIndex(exercise.id);
      _selectedSetIndex[exercise.id] = idx;
    }
    if (idx < 0 || sets[idx].isCompleted) return;

    final restSeconds = _defaultRestSeconds;
    setState(() {
      final set = sets[idx];
      set.isCompleted = true;
      set.completedAt = DateTime.now();
      _completedSets[exercise.id] = (_completedSets[exercise.id] ?? 0) + 1;
      _selectFirstIncompleteSet(exercise.id);
    });
    _startRestTimer(restSeconds);
  }

  void _goToNextIncompleteExercise() {
    if (widget.exercises.isEmpty) return;

    // Prefer next exercise after current, then wrap to first incomplete.
    for (var i = 1; i <= widget.exercises.length; i++) {
      final index = (_currentExerciseIndex + i) % widget.exercises.length;
      if (!_allSetsCompleted(widget.exercises[index])) {
        _goToExercise(index);
        return;
      }
    }
    _endWorkout();
  }

  void _selectSet(String exerciseId, int index) {
    if (_selectedSetIndex[exerciseId] == index) return;
    setState(() {
      _selectedSetIndex[exerciseId] = index;
    });
  }

  int _firstIncompleteSetIndex(String exerciseId) {
    final sets = _exerciseSets[exerciseId] ?? [];
    if (sets.isEmpty) return 0;
    final idx = sets.indexWhere((s) => !s.isCompleted);
    return idx >= 0 ? idx : sets.length - 1;
  }

  void _selectFirstIncompleteSet(String exerciseId) {
    final sets = _exerciseSets[exerciseId];
    if (sets == null || sets.isEmpty) {
      _selectedSetIndex.remove(exerciseId);
      return;
    }
    _selectedSetIndex[exerciseId] = _firstIncompleteSetIndex(exerciseId);
  }

  void _ensureValidSelection(String exerciseId) {
    final sets = _exerciseSets[exerciseId] ?? [];
    if (sets.isEmpty) {
      _selectedSetIndex.remove(exerciseId);
      return;
    }
    final current = _selectedSetIndex[exerciseId];
    if (current == null || current < 0 || current >= sets.length) {
      _selectedSetIndex[exerciseId] = _firstIncompleteSetIndex(exerciseId);
    }
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

  String _setLabelForIndex(int index) {
    if (!_useLetterSetLabels) return '${index + 1}';
    if (index < 26) return String.fromCharCode(65 + index); // A-Z
    // AA, AB… after Z
    final first = index ~/ 26 - 1;
    final second = index % 26;
    return '${String.fromCharCode(65 + first)}${String.fromCharCode(65 + second)}';
  }

  void _showSessionSettingsModal() {
    var draftRest = _defaultRestSeconds;
    var draftLetters = _useLetterSetLabels;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUiSizes.radiusMd),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColorPalette.grey300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Session settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColorPalette.grey800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Default rest time',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColorPalette.grey800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              draftRest = (draftRest - 15).clamp(15, 600);
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Text(
                            '${draftRest}s',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              draftRest = (draftRest + 15).clamp(15, 600);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Slider(
                      value: draftRest.toDouble(),
                      min: 15,
                      max: 180,
                      divisions: 11,
                      label: '${draftRest}s',
                      onChanged: (v) {
                        setModalState(() {
                          draftRest = v.round();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set labels',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColorPalette.grey800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('1, 2, 3'),
                          icon: Icon(Icons.pin_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('A, B, C'),
                          icon: Icon(Icons.sort_by_alpha),
                        ),
                      ],
                      selected: {draftLetters},
                      onSelectionChanged: (next) {
                        setModalState(() {
                          draftLetters = next.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _defaultRestSeconds = draftRest;
                          _useLetterSetLabels = draftLetters;
                          // Keep in-progress rest using the new default only when
                          // remaining time is still at/above previous default.
                          for (final sets in _exerciseSets.values) {
                            for (final set in sets) {
                              set.restTimeSeconds = draftRest;
                            }
                          }
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColorPalette.color2,
                        foregroundColor: AppColorPalette.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUiSizes.buttonRadius,
                          ),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _addSet(ExerciseModel exercise, {bool bumpVersion = false}) {
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
          id: '${exercise.id}_set_${sets.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
          exerciseId: exercise.id,
          reps: sets.isNotEmpty ? sets.last.reps : 10,
          measurementType: unit,
          value: defaultValue,
          restTimeSeconds: 60,
          isCompleted: false,
        ),
      );
      if (bumpVersion) {
        _fieldEpoch[exercise.id] = (_fieldEpoch[exercise.id] ?? 0) + 1;
      }
      _selectFirstIncompleteSet(exercise.id);
    });
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

  Widget _buildExerciseSwapBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColorPalette.grey100.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: AppColorPalette.grey300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < widget.exercises.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _buildExerciseSwapChip(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSwapChip(int index) {
    final exercise = widget.exercises[index];
    final isSelected = index == _currentExerciseIndex;
    final done = _allSetsCompleted(exercise);
    final accent = AppColorPalette.color2;
    final radius = AppUiSizes.buttonRadius;

    return Material(
      color: isSelected
          ? accent
          : done
          ? accent.withValues(alpha: 0.12)
          : AppColorPalette.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: () => _goToExercise(index),
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isSelected || done ? accent : AppColorPalette.grey300,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected
                      ? AppColorPalette.white
                      : done
                      ? accent
                      : AppColorPalette.grey800,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? AppColorPalette.white.withValues(alpha: 0.9)
                        : AppColorPalette.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSequentialNavControls() {
    final exercise = widget.exercises.isEmpty
        ? null
        : widget.exercises[_currentExerciseIndex.clamp(
            0,
            widget.exercises.length - 1,
          )];
    final canAdjustWeight =
        exercise != null &&
        exercise.measurementUnit != 'none' &&
        exercise.measurementUnit != 'seconds';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutStepper(
              label: 'Reps',
              onDecrease: exercise == null
                  ? null
                  : () => _adjustSelectedReps(exercise, -1),
              onIncrease: exercise == null
                  ? null
                  : () => _adjustSelectedReps(exercise, 1),
              decreaseTooltip: 'Decrease reps by 1',
              increaseTooltip: 'Increase reps by 1',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutStepper(
              label: 'Weight',
              decreaseText: '−2.5',
              increaseText: '+2.5',
              onDecrease: canAdjustWeight
                  ? () => _adjustSelectedWeight(exercise, -2.5)
                  : null,
              onIncrease: canAdjustWeight
                  ? () => _adjustSelectedWeight(exercise, 2.5)
                  : null,
              decreaseTooltip: 'Decrease weight by 2.5',
              increaseTooltip: 'Increase weight by 2.5',
            ),
          ),
        ],
      ),
    );
  }

  void _goToExercise(int index) {
    if (index < 0 || index >= widget.exercises.length) return;
    if (index == _currentExerciseIndex) return;
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restDuration = Duration.zero;
      _currentExerciseIndex = index;
      _selectFirstIncompleteSet(widget.exercises[index].id);
    });
    if (!widget.sequentialMode) {
      _tabController.animateTo(index);
    }
  }

  void _showSessionExercisePicker() {
    if (widget.exercises.length <= 1) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColorPalette.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'Session exercises',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColorPalette.grey800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Jump to another exercise if a machine isn’t free',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColorPalette.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: widget.exercises.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final exercise = widget.exercises[index];
                        final isCurrent = index == _currentExerciseIndex;
                        final done = _allSetsCompleted(exercise);
                        final completedSets =
                            _completedSets[exercise.id] ?? 0;
                        final totalSets =
                            _exerciseSets[exercise.id]?.length ?? 0;

                        return ListTile(
                          selected: isCurrent,
                          leading: CircleAvatar(
                            backgroundColor: isCurrent
                                ? AppColorPalette.color2
                                : done
                                ? AppColorPalette.color2.withValues(
                                    alpha: 0.15,
                                  )
                                : AppColorPalette.grey200,
                            foregroundColor: isCurrent
                                ? AppColorPalette.white
                                : done
                                ? AppColorPalette.color2
                                : AppColorPalette.grey700,
                            child: done && !isCurrent
                                ? Icon(Icons.check, size: 18)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          title: Text(
                            exercise.name,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${exercise.muscleGroup} • ${exercise.equipment} · $completedSets/$totalSets sets',
                          ),
                          trailing: isCurrent
                              ? Icon(
                                  Icons.radio_button_checked,
                                  color: AppColorPalette.color2,
                                )
                              : Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            _goToExercise(index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _adjustSelectedReps(ExerciseModel exercise, int delta) {
    setState(() {
      _ensureValidSelection(exercise.id);
      final sets = _exerciseSets[exercise.id];
      if (sets == null || sets.isEmpty) return;
      final idx = _selectedSetIndex[exercise.id] ?? 0;
      if (idx < 0 || idx >= sets.length) return;
      final set = sets[idx];
      set.reps = (set.reps + delta).clamp(0, 999);
      _fieldEpoch[exercise.id] = (_fieldEpoch[exercise.id] ?? 0) + 1;
    });
  }

  void _adjustSelectedWeight(ExerciseModel exercise, double delta) {
    final unit = exercise.measurementUnit;
    if (unit == 'none' || unit == 'seconds') return;

    setState(() {
      _ensureValidSelection(exercise.id);
      final sets = _exerciseSets[exercise.id];
      if (sets == null || sets.isEmpty) return;
      final idx = _selectedSetIndex[exercise.id] ?? 0;
      if (idx < 0 || idx >= sets.length) return;
      final set = sets[idx];
      final current = set.value ?? 0;
      final next = (current + delta).clamp(0.0, 9999.0);
      final rounded = (next * 2).roundToDouble() / 2;
      // Direct assign — updateValue() calls Hive save() and fails for session sets.
      set.value = rounded;
      set.measurementType = unit;
      _fieldEpoch[exercise.id] = (_fieldEpoch[exercise.id] ?? 0) + 1;
    });
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
    // Keep a single accent on this screen (secondary palette color).
    return AppColorPalette.color2;
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
          if (widget.sequentialMode)
            TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: Text('Leave (resume later)'),
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
    } else if (result == 'leave') {
      if (mounted) {
        Navigator.pop(context, {
          'paused': true,
          'exerciseIndex': _currentExerciseIndex,
        });
      }
      return false;
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
          if (widget.sequentialMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pop(context, {
                    'paused': true,
                    'exerciseIndex': _currentExerciseIndex,
                  });
                }
              },
              child: Text('Leave (resume later)'),
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
                foregroundColor: AppColorPalette.grey800,
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
      widget.session.exerciseCompletedSets = {
        for (final ex in widget.exercises)
          ex.id: (_exerciseSets[ex.id] ?? [])
              .where((set) => set.isCompleted)
              .length,
      };
      // Fully finished exercises
      widget.session.completedExerciseIds = widget.exercises
          .where((ex) => _allSetsCompleted(ex))
          .map((ex) => ex.id)
          .toList();
      // Also keep any exercise with completed sets discoverable via completed ids
      // when all sets were finished; history also reads exerciseSets / completed sets.

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

/// Compact − / + control for set count and weight bumps.
class _ShortcutStepper extends StatelessWidget {
  final String label;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String? decreaseText;
  final String? increaseText;
  final String? decreaseTooltip;
  final String? increaseTooltip;

  const _ShortcutStepper({
    required this.label,
    this.onDecrease,
    this.onIncrease,
    this.decreaseText,
    this.increaseText,
    this.decreaseTooltip,
    this.increaseTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onDecrease != null || onIncrease != null;
    final accent = AppColorPalette.color3;
    final radius = AppUiSizes.buttonRadius;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? AppColorPalette.grey300 : AppColorPalette.grey200,
        ),
        borderRadius: BorderRadius.circular(radius),
        color: enabled ? AppColorPalette.white : AppColorPalette.grey100,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? AppColorPalette.grey800
                    : AppColorPalette.textSecondary,
              ),
            ),
          ),
          _stepButton(
            text: decreaseText ?? '−',
            onPressed: onDecrease,
            tooltip: decreaseTooltip,
            accent: accent,
            radius: radius,
          ),
          const SizedBox(width: 4),
          _stepButton(
            text: increaseText ?? '+',
            onPressed: onIncrease,
            tooltip: increaseTooltip,
            accent: accent,
            radius: radius,
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required String text,
    required VoidCallback? onPressed,
    required Color accent,
    required double radius,
    String? tooltip,
  }) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(44, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: accent,
        foregroundColor: AppColorPalette.white,
        disabledBackgroundColor: AppColorPalette.grey200,
        disabledForegroundColor: AppColorPalette.textMuted,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

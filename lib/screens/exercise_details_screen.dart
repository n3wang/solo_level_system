// lib/screens/exercise_details_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/screens/add_edit_exercise_screen.dart';
import 'package:solo_level_system/screens/active_workout_session_screen.dart';
import 'package:solo_level_system/widgets/exercise_set_membership_toggle.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/workout_service.dart';
import 'package:solo_level_system/widgets/common/centered_app_modal.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final ExerciseModel exercise;
  final bool presentedAsModal;

  const ExerciseDetailsScreen({
    super.key,
    required this.exercise,
    this.presentedAsModal = false,
  });

  /// Centered modal used when tapping an exercise from listing screens.
  static Future<void> show(BuildContext context, ExerciseModel exercise) {
    return showCenteredAppModal<void>(
      context: context,
      builder: (ctx) =>
          ExerciseDetailsScreen(exercise: exercise, presentedAsModal: true),
    );
  }

  @override
  _ExerciseDetailsScreenState createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  List<WorkoutSessionModel> _exerciseHistory = [];
  late ExerciseModel _exercise;

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    _loadExerciseHistory();
  }

  ExerciseModel get _liveExercise {
    if (!Hive.isBoxOpen('exercises')) return _exercise;
    final box = Hive.box<ExerciseModel>('exercises');
    return box.get(_exercise.id) ??
        box.values.cast<ExerciseModel?>().firstWhere(
          (ex) => ex?.id == _exercise.id,
          orElse: () => null,
        ) ??
        _exercise;
  }

  void _loadExerciseHistory() async {
    await Hive.openBox<WorkoutSessionModel>('workoutSessions');
    setState(() {
      _exerciseHistory = WorkoutService.sessionsForExercise(_exercise.id);
    });
  }

  /// Fallback when sessions weren't linked but last-workout fields were updated.
  bool get _hasLastWorkoutFallback {
    final ex = _liveExercise;
    return _exerciseHistory.isEmpty &&
        ex.lastWorkoutDate != null &&
        (ex.lastWorkoutReps?.isNotEmpty ?? false);
  }

  int get _timesUsedCount {
    if (_exerciseHistory.isNotEmpty) return _exerciseHistory.length;
    final performed = _liveExercise.timesPerformed;
    if (performed > 0) return performed;
    if (_hasLastWorkoutFallback) return 1;
    return 0;
  }

  DateTime? get _lastUsedAt {
    if (_exerciseHistory.isNotEmpty) return _exerciseHistory.first.startTime;
    return _liveExercise.lastWorkoutDate;
  }

  double? get _bestWeightValue {
    final exercise = _liveExercise;
    final unit = exercise.measurementUnit;
    final showWeight = unit == 'kg' || unit == 'lbs';
    if (!showWeight) {
      return exercise.personalRecord;
    }

    double? best = exercise.personalRecord;

    void consider(double? value) {
      if (value == null || value <= 0) return;
      if (best == null || value > best!) best = value;
    }

    for (final session in _exerciseHistory) {
      final stats = WorkoutService.statsForExerciseInSession(
        session,
        exercise.id,
        measurementUnit: unit,
      );
      consider(stats?.maxWeight);
    }

    for (final weight in exercise.lastWorkoutWeights ?? const <double?>[]) {
      consider(weight);
    }

    return best;
  }

  String get _bestWeightLabel {
    final value = _bestWeightValue;
    if (value == null) return '-';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  Color get _accent => AppColorPalette.color2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.presentedAsModal
          ? Theme.of(context).scaffoldBackgroundColor
          : null,
      appBar: AppBar(
        title: widget.presentedAsModal ? null : Text(_liveExercise.name),
        backgroundColor: widget.presentedAsModal
            ? Theme.of(context).scaffoldBackgroundColor
            : null,
        foregroundColor: widget.presentedAsModal
            ? Theme.of(context).colorScheme.onSurface
            : null,
        elevation: widget.presentedAsModal ? 0 : null,
        scrolledUnderElevation: widget.presentedAsModal ? 0 : null,
        leading: widget.presentedAsModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          ValueListenableBuilder(
            valueListenable: Hive.box<ExerciseModel>('exercises').listenable(),
            builder: (context, Box<ExerciseModel> box, _) {
              final exercise = box.get(_exercise.id) ?? _exercise;
              return IconButton(
                icon: Icon(
                  exercise.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: exercise.isBookmarked ? _accent : null,
                ),
                tooltip: exercise.isBookmarked
                    ? 'Remove bookmark'
                    : 'Bookmark exercise',
                onPressed: () {
                  exercise.toggleBookmark();
                },
              );
            },
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _editExercise),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: _accent),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: _accent)),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExerciseHeader(),
            const SizedBox(height: 24),
            _buildPersonalRecords(),
            const SizedBox(height: 24),
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildExerciseHistory(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "exercise_details_quick_start",
        onPressed: _startQuickWorkout,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Quick Start'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColorPalette.white,
      ),
    );
  }

  Widget _buildExerciseHeader() {
    final exercise = _liveExercise;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WorkoutIconWidget(
                    imageUrl: exercise.imageUrl,
                    size: 80,
                    placeholder: Icon(
                      _getMuscleGroupIcon(exercise.muscleGroup),
                      color: AppColorPalette.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColorPalette.white
                            : AppColorPalette.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.muscleGroup.toUpperCase(),
                      style: TextStyle(
                        color: isDark
                            ? AppColorPalette.grey400
                            : AppColorPalette.grey600,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exercise.difficulty.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColorPalette.grey400
                            : AppColorPalette.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (exercise.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              exercise.description,
              style: TextStyle(fontSize: 16, color: AppColorPalette.grey700),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (exercise.tags.isNotEmpty)
                ...exercise.tags.map(
                  (tag) =>
                      _buildInfoChip(tag.toUpperCase(), Icons.tag, _accent),
                )
              else ...[
                _buildInfoChip(
                  exercise.category.toUpperCase(),
                  Icons.category,
                  _accent,
                ),
                _buildInfoChip(
                  exercise.equipment == 'bodyweight'
                      ? 'BODYWEIGHT'
                      : exercise.equipment.toUpperCase(),
                  Icons.fitness_center,
                  _accent,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ExerciseSetMembershipToggle(
            exerciseId: exercise.id,
            persistImmediately: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecords() {
    final exercise = _liveExercise;
    final lastUsed = _lastUsedAt;
    final timesUsed = _timesUsedCount;
    final accent = _accent;

    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRecordCard(
                  'Best Weight',
                  _bestWeightLabel,
                  exercise.personalRecordUnit ??
                      (exercise.measurementUnit == 'lbs' ? 'lbs' : 'kg'),
                  Icons.fitness_center,
                  accent,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  'Times Used',
                  timesUsed.toString(),
                  timesUsed == 1 ? 'session' : 'sessions',
                  Icons.history,
                  accent,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  'Last Used',
                  lastUsed != null ? _formatDate(lastUsed) : 'Never',
                  '',
                  Icons.access_time,
                  accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty) ...[
                SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 10, color: color)),
              ],
            ],
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: _accent),
              SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColorPalette.white
                          : AppColorPalette.grey900,
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_liveExercise.instructions.isEmpty)
            Text(
              'No instructions provided.',
              style: TextStyle(
                color: AppColorPalette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ..._liveExercise.instructions.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            color: AppColorPalette.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? AppColorPalette.grey300
                                  : AppColorPalette.grey800,
                            ),
                          );
                        },
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

  Widget _buildExerciseHistory() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark
        ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.6)
        : AppColorPalette.white.withValues(alpha: 0.8);

    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: _accent),
              SizedBox(width: 8),
              Text(
                'Recent History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColorPalette.white
                      : AppColorPalette.grey900,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_exerciseHistory.isEmpty && !_hasLastWorkoutFallback)
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  'No workout history for this exercise.',
                  style: TextStyle(
                    color: isDark
                        ? AppColorPalette.grey400
                        : AppColorPalette.grey600,
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            )
          else if (_hasLastWorkoutFallback)
            _buildLastWorkoutFallbackItem()
          else
            ...(_exerciseHistory
                .take(5)
                .map((session) => _buildHistoryItem(session))),
          if (_exerciseHistory.length > 5)
            TextButton(
              onPressed: _viewFullHistory,
              child: Text('View All History'),
            ),
        ],
      ),
    );
  }

  Widget _buildLastWorkoutFallbackItem() {
    final exercise = _liveExercise;
    final reps = exercise.lastWorkoutReps ?? [];
    final weights = exercise.lastWorkoutWeights ?? [];
    final completed = reps.length;
    final totalReps = reps.fold(0, (a, b) => a + b);
    final positiveWeights = weights
        .whereType<double>()
        .where((w) => w > 0)
        .toList();
    final showWeight =
        exercise.measurementUnit == 'kg' || exercise.measurementUnit == 'lbs';
    final avg = positiveWeights.isEmpty
        ? null
        : positiveWeights.reduce((a, b) => a + b) / positiveWeights.length;
    final maxW = positiveWeights.isEmpty
        ? null
        : positiveWeights.reduce((a, b) => a > b ? a : b);
    final maxR = reps.isEmpty ? null : reps.reduce((a, b) => a > b ? a : b);
    final unit = exercise.measurementUnit;

    String fmt(double? v) {
      if (v == null) return '—';
      return v == v.roundToDouble()
          ? '${v.toInt()} $unit'
          : '${v.toStringAsFixed(1)} $unit';
    }

    return _historyCardShell(
      title: 'Last workout',
      subtitle: _formatDate(exercise.lastWorkoutDate!),
      trailing: null,
      stats: [
        _historyStatChip('Reps', '$totalReps', Icons.repeat),
        if (showWeight && avg != null)
          _historyStatChip('Avg', fmt(avg), Icons.balance),
        if (maxR != null)
          _historyStatChip('Max reps', '$maxR', Icons.arrow_upward),
        if (showWeight && maxW != null)
          _historyStatChip('Max wt', fmt(maxW), Icons.fitness_center),
        _historyStatChip('Sets', '$completed', Icons.layers_outlined),
      ],
    );
  }

  Widget _historyCardShell({
    required String title,
    required String subtitle,
    required String? trailing,
    required List<Widget> stats,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBgColor = isDark
        ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.4)
        : AppColorPalette.grey50;
    final borderColor = isDark
        ? AppColorPalette.grey700
        : AppColorPalette.grey200;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: _accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColorPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    color: isDark
                        ? AppColorPalette.grey400
                        : AppColorPalette.grey600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: stats),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem(WorkoutSessionModel session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBgColor = isDark
        ? AppColorPalette.backgroundDarkSurface.withValues(alpha: 0.4)
        : AppColorPalette.grey50;
    final borderColor = isDark
        ? AppColorPalette.grey700
        : AppColorPalette.grey200;
    final exercise = _liveExercise;
    final stats = WorkoutService.statsForExerciseInSession(
      session,
      exercise.id,
      measurementUnit: exercise.measurementUnit,
    );
    final showWeight =
        exercise.measurementUnit == 'kg' || exercise.measurementUnit == 'lbs';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.isCompleted || (stats?.completedSets ?? 0) > 0
                    ? Icons.check_circle
                    : Icons.cancel,
                color: session.isCompleted || (stats?.completedSets ?? 0) > 0
                    ? _accent
                    : AppColorPalette.grey600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.routineName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _formatDate(session.startTime),
                      style: TextStyle(
                        color: AppColorPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${session.durationMinutes} min',
                style: TextStyle(
                  color: isDark
                      ? AppColorPalette.grey400
                      : AppColorPalette.grey600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (stats != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _historyStatChip('Reps', '${stats.totalReps}', Icons.repeat),
                if (showWeight && stats.averageWeight != null)
                  _historyStatChip(
                    'Avg',
                    stats.averageWeightLabel,
                    Icons.balance,
                  ),
                if (stats.maxReps != null)
                  _historyStatChip(
                    'Max reps',
                    '${stats.maxReps}',
                    Icons.arrow_upward,
                  ),
                if (showWeight && stats.maxWeight != null)
                  _historyStatChip(
                    'Max wt',
                    stats.maxWeightLabel,
                    Icons.fitness_center,
                  ),
                _historyStatChip(
                  'Sets',
                  '${stats.completedSets}',
                  Icons.layers_outlined,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColorPalette.grey200.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColorPalette.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColorPalette.color2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMuscleGroupColor(String muscleGroup) {
    return _accent;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _editExercise() async {
    final result = await AddEditExerciseScreen.showAsModal(
      context,
      exercise: _liveExercise,
      nested: true,
    );

    if (!mounted) return;

    // Tap outside dismisses edit AND detail
    if (result == null) {
      Navigator.pop(context);
      return;
    }

    // Back / discard returns to this detail modal without saving
    if (result == 'discard') {
      return;
    }

    // Saved or duplicated — refresh from Hive
    setState(() {
      _exercise = _liveExercise;
    });
    _loadExerciseHistory();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'delete':
        _deleteExercise();
        break;
    }
  }

  void _deleteExercise() {
    final exercise = _liveExercise;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Exercise'),
        content: Text('Are you sure you want to delete "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              exercise.delete();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail
              showAppSnack(
      context,
      text: 'Exercise deleted',
    );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColorPalette.color2),
            ),
          ),
        ],
      ),
    );
  }

  void _startQuickWorkout() {
    final exercise = _liveExercise;
    final session = WorkoutSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineId: 'quick_${exercise.id}',
      routineName: 'Quick: ${exercise.name}',
      startTime: DateTime.now(),
      durationMinutes: 0,
      completedExerciseIds: [],
      exerciseCompletedSets: {},
      isCompleted: false,
      status: 'active',
      totalSetsCompleted: 0,
      totalRepsCompleted: 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ActiveWorkoutSessionScreen(session: session, exercises: [exercise]),
      ),
    );
  }

  void _viewFullHistory() {
    showAppSnack(
      context,
      text: 'Full history view not implemented yet',
    );
  }
}

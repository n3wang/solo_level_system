// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/habit_tracker_model.dart';
import 'package:solo_level_system/screens/motivation_hub_screen.dart';
import 'package:solo_level_system/widgets/pomodoro/session_recording_preview.dart';

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Week';
  final List<String> _periods = ['Today', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox.shrink(),
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Focus'),
            Tab(text: 'Workouts'),
            Tab(text: 'Motivation'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Time period selector below tabs
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUiSizes.lg,
              vertical: AppUiSizes.sm,
            ),
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              onSelected: (period) {
                setState(() => _selectedPeriod = period);
              },
              itemBuilder: (context) => _periods
                  .map(
                    (period) =>
                        PopupMenuItem(value: period, child: Text(period)),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUiSizes.sm,
                  vertical: AppUiSizes.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedPeriod),
                    const SizedBox(width: AppUiSizes.xs),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildFocusTab(),
                _buildWorkoutsTab(),
                const MotivationHubScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder(
      future: Future.wait([
        _ensureBoxIsOpen<PomodoroModel>('pomodoros'),
        _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions'),
        _ensureBoxIsOpen<HabitTrackerModel>('habits'),
        _ensureBoxIsOpen<EnhancedAudioModel>('audioFiles'),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<PomodoroModel>('pomodoros').listenable(),
          builder: (context, pomodoroBox, _) {
            return ValueListenableBuilder(
              valueListenable: Hive.box<WorkoutSessionModel>(
                'workoutSessions',
              ).listenable(),
              builder: (context, workoutBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<HabitTrackerModel>(
                    'habits',
                  ).listenable(),
                  builder: (context, habitBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: Hive.box<EnhancedAudioModel>(
                        'audioFiles',
                      ).listenable(),
                      builder: (context, audioBox, _) {
                        final pomodoros = _filterSessionsByPeriod(
                          pomodoroBox.values.toList(),
                        );
                        final workouts = _filterWorkoutsByPeriod(
                          workoutBox.values.toList(),
                        );
                        final habits = habitBox.values
                            .where((h) => h.isActive)
                            .toList();
                        final sessionAudios = _filterAudioByPeriod(
                          audioBox.values.toList(),
                        );

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(AppUiSizes.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuickStats(pomodoros, workouts, habits),
                              const SizedBox(height: AppUiSizes.xxl),
                              _buildWeeklyOverview(pomodoros),
                              const SizedBox(height: AppUiSizes.xxl),
                              _buildGoalsProgress(pomodoros, workouts, habits),
                              const SizedBox(height: AppUiSizes.xxl),
                              _buildSessionAudioRecordingsCard(sessionAudios),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFocusTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<PomodoroModel>('pomodoros'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading focus data: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<PomodoroModel>('pomodoros').listenable(),
          builder: (context, Box<PomodoroModel> box, _) {
            final sessions = box.values.toList();
            final filteredSessions = _filterSessionsByPeriod(sessions);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppUiSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFocusStats(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildFocusChart(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildProjectBreakdown(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildStreakInfo(sessions),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkoutsTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading workout data: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<WorkoutSessionModel>(
            'workoutSessions',
          ).listenable(),
          builder: (context, Box<WorkoutSessionModel> box, _) {
            final sessions = box.values.toList();
            final filteredSessions = _filterWorkoutsByPeriod(sessions);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppUiSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkoutStats(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildWorkoutChart(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildPersonalRecords(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildMuscleGroupBreakdown(filteredSessions),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStats(
    List<PomodoroModel> pomodoros,
    List<WorkoutSessionModel> workouts,
    List<HabitTrackerModel> habits,
  ) {
    final focusSessions = pomodoros.length;
    final completedWorkouts = workouts.where((w) => w.isCompleted).length;
    final completedHabits = habits.where((h) => h.isCompleted).length;
    final totalHabits = habits.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats - $_selectedPeriod',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Focus Sessions',
                    '$focusSessions',
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Workouts',
                    '$completedWorkouts',
                    Icons.fitness_center,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Habits',
                    '$completedHabits/$totalHabits',
                    Icons.track_changes,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppUiSizes.sm),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: AppColorPalette.fontSizeTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: AppColorPalette.fontSizeSmall,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWeeklyOverview(List<PomodoroModel> pomodoros) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekData = List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      final dayPomodoros = pomodoros
          .where(
            (p) =>
                p.startTime.year == day.year &&
                p.startTime.month == day.month &&
                p.startTime.day == day.day,
          )
          .length;
      return dayPomodoros;
    });

    final maxSessions = weekData.isNotEmpty
        ? weekData.reduce((a, b) => a > b ? a : b)
        : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week - Focus Sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final dayNames = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  final sessions = weekData[index];
                  final height = maxSessions > 0
                      ? (sessions / maxSessions) * 100
                      : 0.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: height.clamp(5.0, 100.0),
                        decoration: BoxDecoration(
                          color: sessions > 0
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppUiSizes.xs),
                        ),
                      ),
                      const SizedBox(height: AppUiSizes.sm),
                      Text(
                        sessions.toString(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: AppColorPalette.fontSizeXSmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dayNames[index],
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: AppColorPalette.fontSizeSmall,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsProgress(
    List<PomodoroModel> pomodoros,
    List<WorkoutSessionModel> workouts,
    List<HabitTrackerModel> habits,
  ) {
    final todayPomodoros = pomodoros.where((p) {
      final today = DateTime.now();
      return p.startTime.year == today.year &&
          p.startTime.month == today.month &&
          p.startTime.day == today.day;
    }).length;

    final weeklyWorkouts = workouts.where((w) => w.isCompleted).length;
    final completedHabits = habits.where((h) => h.isCompleted).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goals Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            _buildGoalItem('Daily Focus Sessions', todayPomodoros, 5),
            _buildGoalItem(
              '$_selectedPeriod Workouts',
              weeklyWorkouts,
              _selectedPeriod == 'Week'
                  ? 4
                  : _selectedPeriod == 'Today'
                  ? 1
                  : 15,
            ),
            _buildGoalItem(
              'Habit Completion',
              completedHabits,
              habits.isNotEmpty ? habits.length : 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionAudioRecordingsCard(List<EnhancedAudioModel> audios) {
    final sorted = [...audios]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Audio Recordings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.sm),
            Text(
              '${sorted.length} recording${sorted.length == 1 ? '' : 's'} in $_selectedPeriod',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppUiSizes.md),
            if (sorted.isEmpty)
              Text(
                'No session recordings for this period yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              )
            else
              Column(
                children: sorted
                    .map(
                      (audio) => Padding(
                        padding: const EdgeInsets.only(bottom: AppUiSizes.sm),
                        child: SessionRecordingPreview(audio: audio),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String goal, int current, int target) {
    final progress = current / target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppUiSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(goal), Text('$current/$target')],
          ),
          const SizedBox(height: AppUiSizes.xs),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.16),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusStats(List<PomodoroModel> sessions) {
    final totalSessions = sessions.length;
    final totalMinutes = totalSessions * 25; // Assuming 25-minute sessions
    final avgPerDay = totalSessions / 7; // Weekly average

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Sessions',
            '$totalSessions',
            Icons.play_circle,
          ),
        ),
        Expanded(
          child: _buildStatCard('Minutes', '$totalMinutes', Icons.timer),
        ),
        Expanded(
          child: _buildStatCard(
            'Avg/Day',
            avgPerDay.toStringAsFixed(1),
            Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppUiSizes.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: AppColorPalette.fontSizeSmall,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusChart(List<PomodoroModel> sessions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Sessions Over Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            SizedBox(
              height: 200,
              child: Center(child: Text('Chart would go here')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectBreakdown(List<PomodoroModel> sessions) {
    // Group sessions by project
    final projectStats = <String, int>{};
    final projectNames = <String, String>{};

    for (final session in sessions) {
      if (session.project_id != null && session.project_name != null) {
        final projectId = session.project_id!;
        projectStats[projectId] = (projectStats[projectId] ?? 0) + 1;
        projectNames[projectId] = session.project_name!;
      } else {
        // Sessions without project
        projectStats['unassigned'] = (projectStats['unassigned'] ?? 0) + 1;
        projectNames['unassigned'] = 'Unassigned';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            projectStats.isEmpty
                ? Text(
                    'No project data available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  )
                : Column(
                    children: projectStats.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppUiSizes.xs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _getProjectColor(entry.key),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(width: AppUiSizes.sm),
                                    Text(
                                      projectNames[entry.key] ?? 'Unknown',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        fontSize: AppColorPalette.fontSizeBody,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${entry.value} sessions',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Color _getProjectColor(String projectId) {
    // Color assignment from centralized palette.
    final colors = [
      AppColorPalette.color2,
      AppColorPalette.color3,
      AppColorPalette.color4,
      AppColorPalette.color1,
      AppColorPalette.color5,
      AppColorPalette.accent,
    ];

    if (projectId == 'unassigned') return AppColorPalette.grey500;

    final hash = projectId.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildStreakInfo(List<PomodoroModel> sessions) {
    int currentStreak = _calculateCurrentStreak(sessions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Streak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: currentStreak > 0
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 32,
                ),
                const SizedBox(width: AppUiSizes.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStreak > 0 ? '$currentStreak days' : 'No streak',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: AppColorPalette.fontSizeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Current streak',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateCurrentStreak(List<PomodoroModel> sessions) {
    if (sessions.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasSessions = sessions.any(
        (s) =>
            s.startTime.year == checkDate.year &&
            s.startTime.month == checkDate.month &&
            s.startTime.day == checkDate.day,
      );

      if (hasSessions) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  Widget _buildWorkoutStats(List<WorkoutSessionModel> sessions) {
    final completedSessions = sessions.where((s) => s.isCompleted).toList();
    final totalHours =
        completedSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes) /
        60;
    final totalCalories = completedSessions.fold<int>(
      0,
      (sum, s) => sum + s.caloriesBurned,
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Workouts',
            '${completedSessions.length}',
            Icons.fitness_center,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Hours',
            totalHours > 0 ? totalHours.toStringAsFixed(1) : '0',
            Icons.schedule,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Calories',
            '$totalCalories',
            Icons.local_fire_department,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutChart(List<WorkoutSessionModel> sessions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Frequency',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            sessions.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'No workout data yet. Start your first workout!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        '${sessions.length} total sessions recorded',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: AppColorPalette.fontSizeMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecords(List<WorkoutSessionModel> sessions) {
    final recordSessions = sessions
        .where((s) => s.personalRecordsSet.isNotEmpty)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Records',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            recordSessions.isEmpty
                ? Text(
                    'No personal records set yet. Keep pushing!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        '🏆 ${recordSessions.fold<int>(0, (sum, s) => sum + s.personalRecordsSet.length)} records set',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: AppColorPalette.fontSizeMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppUiSizes.sm),
                      Text(
                        'Across ${recordSessions.length} sessions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupBreakdown(List<WorkoutSessionModel> sessions) {
    final locations = <String, int>{};
    for (final session in sessions.where((s) => s.location != null)) {
      locations[session.location!] = (locations[session.location!] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Locations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            locations.isEmpty
                ? Text(
                    'No location data available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  )
                : Column(
                    children: locations.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppUiSizes.xs,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.capitalizeFirst()),
                            Text('${entry.value} sessions'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  List<PomodoroModel> _filterSessionsByPeriod(List<PomodoroModel> sessions) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = now.subtract(Duration(days: 7));
    }

    return sessions
        .where((session) => session.startTime.isAfter(startDate))
        .toList();
  }

  List<WorkoutSessionModel> _filterWorkoutsByPeriod(
    List<WorkoutSessionModel> sessions,
  ) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = now.subtract(Duration(days: 7));
    }

    return sessions
        .where((session) => session.startTime.isAfter(startDate))
        .toList();
  }

  List<EnhancedAudioModel> _filterAudioByPeriod(
    List<EnhancedAudioModel> audios,
  ) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = now.subtract(Duration(days: 7));
    }

    return audios
        .where(
          (audio) =>
              audio.createdAt.isAfter(startDate) &&
              (audio.category == null || audio.category == 'session'),
        )
        .toList();
  }

  // Helper method to ensure Hive boxes are opened
  Future<void> _ensureBoxIsOpen<T>(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<T>(boxName);
      }
    } catch (e) {
      print('Error opening box $boxName: $e');
      rethrow;
    }
  }
}

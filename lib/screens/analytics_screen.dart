// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/screens/cards_hub_screen.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/motivation_points_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';
import 'package:solo_level_system/widgets/cards/create_reward_dialog.dart';
import 'package:solo_level_system/widgets/pomodoro/session_recording_preview.dart';
import 'package:solo_level_system/widgets/common/standard_tab_app_bar.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/common/stats_period_chips.dart';

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
  StatsPeriod _selectedPeriod = StatsPeriod.week;
  late final Future<void> _overviewBoxesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _overviewBoxesFuture = Future.wait([
      _ensureBoxIsOpen<PomodoroModel>('pomodoros'),
      _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions'),
      _ensureBoxIsOpen<CardModel>('motivationItems'),
      _ensureBoxIsOpen<RewardModel>('rewards'),
      _ensureBoxIsOpen<UserProgressModel>('userProgress'),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardTabAppBar(
        controller: _tabController,
        labels: const ['Overview', 'Cards', 'Focus', 'Workouts'],
        isScrollable: false,
      ),
      floatingActionButton:
          (_tabController.index == 0 || _tabController.index == 1)
          ? FloatingActionButton.extended(
              onPressed: () => showCreateRewardDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: Column(
        children: [
          // Period picker on Focus/Workouts; Cards shows points; Overview has neither.
          if (_tabController.index == 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppUiSizes.lg,
                vertical: AppUiSizes.sm,
              ),
              alignment: Alignment.centerLeft,
              child: _buildMotivationPointsHeader(),
            )
          else if (_tabController.index == 2 || _tabController.index == 3)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppUiSizes.lg,
                vertical: AppUiSizes.sm,
              ),
              child: StatsPeriodChips(
                value: _selectedPeriod,
                onChanged: (period) => setState(() => _selectedPeriod = period),
              ),
            ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                const CardsHubScreen(),
                _buildFocusTab(),
                _buildWorkoutsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationPointsHeader() {
    if (!Hive.isBoxOpen('userProgress')) {
      return const SizedBox.shrink();
    }
    final progressBox = Hive.box<UserProgressModel>('userProgress');
    final txOpen = Hive.isBoxOpen('motivationPointsTransactions');

    Widget buildLabel() {
      final progress = progressBox.get('progress') ?? UserProgressModel();
      final summary = MotivationPointsService.summary();
      final scheme = Theme.of(context).colorScheme;
      return Text(
        '${progress.availablePoints} (+${summary.lastWeekEarned}/-${summary.lastWeekSpent} lw)',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (!txOpen) {
      return ValueListenableBuilder(
        valueListenable: progressBox.listenable(),
        builder: (_, __, ___) => buildLabel(),
      );
    }

    final txBox = Hive.box<MotivationPointsTransactionModel>(
      'motivationPointsTransactions',
    );
    return ValueListenableBuilder(
      valueListenable: progressBox.listenable(),
      builder: (_, __, ___) {
        return ValueListenableBuilder(
          valueListenable: txBox.listenable(),
          builder: (_, __, ___) => buildLabel(),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder(
      future: _overviewBoxesFuture,
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
                  valueListenable: Hive.box<CardModel>(
                    'motivationItems',
                  ).listenable(),
                  builder: (context, motivationBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: Hive.box<RewardModel>(
                        'rewards',
                      ).listenable(),
                      builder: (context, rewardsBox, _) {
                        final catalog = CardRepository.build(
                          cards: motivationBox.values.toList(),
                          rewards: rewardsBox.values.toList(),
                        );

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(AppUiSizes.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWeeklyOverview(
                                pomodoroBox.values.toList(),
                                workoutBox.values.toList(),
                              ),
                              const SizedBox(height: AppUiSizes.xxl),
                              _OverviewNewCardsSection(catalog: catalog),
                              // Extra space so FAB does not cover the last row.
                              const SizedBox(height: 72),
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
      future: Future.wait([
        _ensureBoxIsOpen<PomodoroModel>('pomodoros'),
        _ensureBoxIsOpen<EnhancedAudioModel>('audioFiles'),
      ]),
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
            return ValueListenableBuilder(
              valueListenable: Hive.box<EnhancedAudioModel>(
                'audioFiles',
              ).listenable(),
              builder: (context, Box<EnhancedAudioModel> audioBox, _) {
                final sessions = box.values.toList();
                final filteredSessions = _filterSessionsByPeriod(sessions);
                final sessionAudios = _filterAudiosByPeriod(
                  audioBox.values.where(_isSessionRecording).toList(),
                );

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

  Widget _buildWeeklyOverview(
    List<PomodoroModel> pomodoros,
    List<WorkoutSessionModel> workouts,
  ) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final focusMinutes = List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      return pomodoros
          .where((p) => _isSameDay(p.startTime, day))
          .fold<int>(0, (sum, p) => sum + p.minutesSpent);
    });
    final workoutMinutes = List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      return workouts
          .where((w) => w.isCompleted && _isSameDay(w.startTime, day))
          .fold<int>(0, (sum, w) => sum + w.durationMinutes);
    });

    // workout = red/color1, focus = blue/color2 (matches mockup)
    final workoutColor = AppColorPalette.color1;
    final focusColor = AppColorPalette.color2;
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const labelWidth = 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeatmapRow(
          label: 'workout',
          color: workoutColor,
          values: workoutMinutes,
          labelWidth: labelWidth,
        ),
        const SizedBox(height: AppUiSizes.sm),
        _buildHeatmapRow(
          label: 'focus',
          color: focusColor,
          values: focusMinutes,
          labelWidth: labelWidth,
        ),
        const SizedBox(height: AppUiSizes.md),
        Row(
          children: [
            const SizedBox(width: labelWidth),
            ...List.generate(7, (index) {
              final day = startOfWeek.add(Duration(days: index));
              final isFirst = index == 0;
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      dayNames[index],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: AppColorPalette.fontSizeSmall,
                      ),
                    ),
                    if (isFirst)
                      Text(
                        '${day.month}/${day.day}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: AppColorPalette.fontSizeXSmall,
                          color: AppColorPalette.textSecondary,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmapRow({
    required String label,
    required Color color,
    required List<int> values,
    required double labelWidth,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildMinutesLegendChip(label, color),
          ),
        ),
        ...List.generate(7, (index) {
          final minutes = values[index];
          return Expanded(
            child: Center(
              child: minutes > 0
                  ? _buildDayMinuteChip('$minutes', color)
                  : const SizedBox(height: 22),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMinutesLegendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDayMinuteChip(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
              '${sorted.length} recording${sorted.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppUiSizes.md),
            if (sorted.isEmpty)
              Text(
                'No session recordings for this period.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              )
            else
              Column(
                children: sorted
                    .map(
                      (audio) => Padding(
                        padding: const EdgeInsets.only(bottom: AppUiSizes.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatRecordingDate(audio.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                            const SizedBox(height: AppUiSizes.xs),
                            SessionRecordingPreview(audio: audio),
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

  Widget _buildFocusStats(List<PomodoroModel> sessions) {
    final totalSessions = sessions.length;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.minutesSpent,
    );
    final avgMinutesPerDay = totalMinutes / 7;

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
            'Avg min/Day',
            avgMinutesPerDay.toStringAsFixed(0),
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize:
                                                AppColorPalette.fontSizeBody,
                                          ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${entry.value} sessions',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
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
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
  bool _isSessionRecording(EnhancedAudioModel audio) {
    return audio.category == null ||
        audio.category == 'session' ||
        audio.tags.contains('session');
  }

  String _formatRecordingDate(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$mm/$dd/${local.year} $hh:$min';
  }

  List<PomodoroModel> _filterSessionsByPeriod(List<PomodoroModel> sessions) {
    final range = StatsPeriodRange.forPeriod(_selectedPeriod);
    return sessions.where((s) => range.contains(s.startTime)).toList();
  }

  List<EnhancedAudioModel> _filterAudiosByPeriod(
    List<EnhancedAudioModel> audios,
  ) {
    final range = StatsPeriodRange.forPeriod(_selectedPeriod);
    return audios.where((a) => range.contains(a.createdAt)).toList();
  }

  List<WorkoutSessionModel> _filterWorkoutsByPeriod(
    List<WorkoutSessionModel> sessions,
  ) {
    final range = StatsPeriodRange.forPeriod(_selectedPeriod);
    return sessions.where((s) => range.contains(s.startTime)).toList();
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

/// New Cards filters + grid. Own [State] so period/type changes only blank
/// this section — not the whole Overview (avoids FutureBuilder reload flash).
class _OverviewNewCardsSection extends StatefulWidget {
  final List<CatalogCard> catalog;

  const _OverviewNewCardsSection({required this.catalog});

  @override
  State<_OverviewNewCardsSection> createState() =>
      _OverviewNewCardsSectionState();
}

class _OverviewNewCardsSectionState extends State<_OverviewNewCardsSection> {
  String _filter = 'all';
  StatsPeriod _period = StatsPeriod.week;

  DateTime _acquiredAt(CatalogCard card) {
    final item = card.sourceItem;
    if (item != null) {
      if (item.acquiredAt != null) return item.acquiredAt!;
      if (item.acquisitionHistory.isNotEmpty) {
        return item.acquisitionHistory.last;
      }
      return item.createdAt;
    }
    final reward = card.sourceReward;
    if (reward != null) {
      return reward.purchasedAt ?? reward.createdAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isDefaultStarter(CatalogCard card) {
    final item = card.sourceItem;
    if (item == null) return false;
    if (!item.isStarter) return false;
    return item.acquisitionCount <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final range = StatsPeriodRange.forPeriod(_period);
    final inPeriod = <CatalogCard>[];
    for (final c in widget.catalog) {
      if (!c.isAcquired) continue;
      if (_isDefaultStarter(c)) continue;
      if (!range.contains(_acquiredAt(c))) continue;
      inPeriod.add(c);
    }

    final presentTypes = <String>{for (final c in inPeriod) c.typeWire};
    // Keep chips stable; if current type isn't present, show empty grid under
    // that filter without a parent rebuild / filter snap (user can pick another).
    final effectiveFilter =
        (_filter != 'all' &&
            _filter != kCollectibleBookmarkFilter &&
            !presentTypes.contains(_filter))
        ? 'all'
        : _filter;
    if (effectiveFilter != _filter) {
      // Sync quietly after this frame without cascading Overview reloads.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _filter == effectiveFilter) return;
        setState(() => _filter = effectiveFilter);
      });
    }

    final acquired = inPeriod.where((c) {
      if (effectiveFilter == kCollectibleBookmarkFilter) {
        return c.isBookmarked;
      }
      if (effectiveFilter != 'all' && c.typeWire != effectiveFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byBookmark = CardRepository.compareBookmarkedFirst(a, b);
        if (byBookmark != 0) return byBookmark;
        return _acquiredAt(b).compareTo(_acquiredAt(a));
      });

    UserProgressModel progress = UserProgressModel();
    if (Hive.isBoxOpen('userProgress')) {
      progress =
          Hive.box<UserProgressModel>('userProgress').get('progress') ??
          progress;
    }

    final typeOptions = <SettingsRectChipOption<String>>[
      const SettingsRectChipOption(value: 'all', label: 'all'),
      const SettingsRectChipOption(
        value: kCollectibleBookmarkFilter,
        label: '',
        icon: Icons.bookmark,
      ),
      for (final t in kCollectibleTypeFilters)
        if (presentTypes.contains(t))
          SettingsRectChipOption(value: t, label: t),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Cards:',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColorPalette.textSecondary),
        ),
        const SizedBox(height: AppUiSizes.sm),
        StatsPeriodChips(
          value: _period,
          onChanged: (period) => setState(() => _period = period),
        ),
        const SizedBox(height: AppUiSizes.sm),
        SettingsRectChipGroup<String>(
          size: SettingsRectChipSize.compact,
          spacing: AppUiSizes.xs,
          runSpacing: AppUiSizes.xs,
          value: effectiveFilter,
          onChanged: (v) => setState(() => _filter = v),
          options: typeOptions,
        ),
        const SizedBox(height: AppUiSizes.md),
        if (acquired.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppUiSizes.lg),
              child: Text(
                'No collectibles acquired ${StatsPeriodRange.emptyLabel(_period)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColorPalette.textSecondary,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            key: ValueKey('new-cards-$_period-$effectiveFilter'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: acquired.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppUiSizes.md,
              mainAxisSpacing: AppUiSizes.md,
              childAspectRatio: CollectibleCardLayout.aspectRatio,
            ),
            itemBuilder: (context, index) {
              final card = acquired[index];
              return CollectibleCardTile(
                card: card,
                availablePoints: progress.availablePoints,
                onTap: () => showCollectibleCardDetail(
                  context: context,
                  card: card,
                  userProgress: progress,
                ),
              );
            },
          ),
      ],
    );
  }
}

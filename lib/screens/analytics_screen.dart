// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/models/project_model.dart';
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
import 'package:solo_level_system/utils/stats_breakdown.dart';
import 'package:solo_level_system/widgets/analytics/stacked_period_bar_chart.dart';

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
        _ensureBoxIsOpen<ProjectModel>('projects'),
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
                final previousSessions = _filterSessionsByPreviousPeriod(
                  sessions,
                );
                final sessionAudios = _filterAudiosByPeriod(
                  audioBox.values.where(_isSessionRecording).toList(),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppUiSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFocusStats(filteredSessions, previousSessions),
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
      future: Future.wait([
        _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions'),
        _ensureBoxIsOpen<WorkoutSetCategoryModel>('workoutSetCategories'),
      ]),
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
            final previousSessions = _filterWorkoutsByPreviousPeriod(sessions);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppUiSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkoutStats(filteredSessions, previousSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildWorkoutChart(filteredSessions),
                  const SizedBox(height: AppUiSizes.xxl),
                  _buildWorkoutStreakInfo(sessions),
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
    final today = DateTime(now.year, now.month, now.day);
    // Rolling 7 days ending today (oldest on the left, today on the right).
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    final samples = AppEnvironment.is_test
        ? _testHeatmapSamplesForPastDays(today, dayCount: 25)
        : const <DateTime, ({int focus, int workout})>{};

    final focusMinutes = <int>[];
    final workoutMinutes = <int>[];
    for (final day in days) {
      var focus = pomodoros
          .where((p) => _isSameDay(p.startTime, day))
          .fold<int>(0, (sum, p) => sum + p.minutesSpent);
      var workout = workouts
          .where((w) => w.isCompleted && _isSameDay(w.startTime, day))
          .fold<int>(0, (sum, w) => sum + w.durationMinutes);

      final sample = samples[day];
      if (sample != null) {
        if (focus == 0) focus = sample.focus;
        if (workout == 0) workout = sample.workout;
      }
      focusMinutes.add(focus);
      workoutMinutes.add(workout);
    }

    // workout = red/color1, focus = blue/color2 (matches mockup)
    final workoutColor = AppColorPalette.color1;
    final focusColor = AppColorPalette.color2;
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _heatmapLayoutForWidth(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: layout.totalWidth,
                child: Column(
                  children: [
                    _buildHeatmapRow(
                      color: workoutColor,
                      values: workoutMinutes,
                      cellSize: layout.cellSize,
                      gap: layout.gap,
                    ),
                    SizedBox(height: layout.gap),
                    _buildHeatmapRow(
                      color: focusColor,
                      values: focusMinutes,
                      cellSize: layout.cellSize,
                      gap: layout.gap,
                    ),
                    const SizedBox(height: AppUiSizes.sm),
                    Row(
                      children: [
                        for (var index = 0; index < days.length; index++) ...[
                          if (index > 0) SizedBox(width: layout.gap),
                          SizedBox(
                            width: layout.cellSize,
                            child: Column(
                              children: [
                                Text(
                                  dayNames[days[index].weekday - 1],
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontSize: AppColorPalette.fontSizeSmall,
                                        fontWeight: index == days.length - 1
                                            ? FontWeight.w700
                                            : null,
                                      ),
                                ),
                                Text(
                                  '${days[index].month}/${days[index].day}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize:
                                            AppColorPalette.fontSizeXSmall,
                                        color: AppColorPalette.textSecondary,
                                        fontWeight: index == days.length - 1
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppUiSizes.md),
            Row(
              children: [
                _buildMinutesLegendChip('workout', workoutColor),
                const SizedBox(width: AppUiSizes.sm),
                _buildMinutesLegendChip('focus', focusColor),
              ],
            ),
          ],
        );
      },
    );
  }

  /// GitHub-style square cells with a small gap, centered in [maxWidth].
  ({double cellSize, double gap, double totalWidth}) _heatmapLayoutForWidth(
    double maxWidth,
  ) {
    const cellCount = 7;
    const gap = 4.0;
    const horizontalInset = AppUiSizes.xl * 2;
    final usable = (maxWidth - horizontalInset).clamp(0.0, maxWidth);
    final raw = (usable - gap * (cellCount - 1)) / cellCount;
    final cellSize = raw.clamp(28.0, 44.0);
    final totalWidth = cellSize * cellCount + gap * (cellCount - 1);
    return (cellSize: cellSize, gap: gap, totalWidth: totalWidth);
  }

  /// Deterministic sample focus/workout minutes for [dayCount] days ending
  /// at [today] (inclusive), keyed by date-only [DateTime].
  Map<DateTime, ({int focus, int workout})> _testHeatmapSamplesForPastDays(
    DateTime today, {
    int dayCount = 25,
  }) {
    final map = <DateTime, ({int focus, int workout})>{};
    for (var i = 0; i < dayCount; i++) {
      final day = today.subtract(Duration(days: i));
      // Stable pseudo-random from day ordinal so hot reload stays consistent.
      final seed = day.year * 10000 + day.month * 100 + day.day;
      final focus = (seed * 7) % 5 == 0 ? 0 : 15 + (seed % 4) * 10;
      final workout = (seed * 11) % 6 == 0 ? 0 : 20 + (seed % 5) * 10;
      map[day] = (focus: focus, workout: workout);
    }
    return map;
  }

  Widget _buildHeatmapRow({
    required Color color,
    required List<int> values,
    required double cellSize,
    required double gap,
  }) {
    final maxMinutes = values.fold<int>(0, (m, v) => v > m ? v : m);

    final cells = <Widget>[];
    for (var index = 0; index < values.length; index++) {
      if (index > 0) cells.add(SizedBox(width: gap));
      final minutes = values[index];
      // Relative to the strongest day in this visible row (0 when empty).
      final intensity = maxMinutes <= 0 || minutes <= 0
          ? 0.0
          : (minutes / maxMinutes).clamp(0.0, 1.0);
      cells.add(
        _buildDayMinuteChip(
          minutes > 0 ? '$minutes' : '',
          color,
          intensity: intensity,
          size: cellSize,
        ),
      );
    }
    return Row(children: cells);
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

  /// [intensity] is 0–1 vs max minutes in the same row (day comparison).
  /// Empty days render a muted square (GitHub-style contribution cell).
  Widget _buildDayMinuteChip(
    String value,
    Color color, {
    required double intensity,
    required double size,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = value.isEmpty;
    // Floor so low days stay readable; ceiling keeps the hottest day strong.
    final fill = isEmpty
        ? scheme.onSurface.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.22 + (intensity * 0.68));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        // Near-square GitHub cells use a tight radius.
        borderRadius: BorderRadius.circular(3),
      ),
      child: isEmpty
          ? null
          : Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: size >= 36 ? 11 : 10,
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

  Widget _buildFocusStats(
    List<PomodoroModel> sessions,
    List<PomodoroModel> previous,
  ) {
    final totalSessions = sessions.length;
    final prevSessions = previous.length;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.minutesSpent,
    );
    final prevMinutes = previous.fold<int>(
      0,
      (sum, s) => sum + s.minutesSpent,
    );
    final days = StatsPeriodRange.dayCount(_selectedPeriod);
    final prevDays = StatsPeriodRange.previousDayCount(_selectedPeriod);
    final avg = (totalMinutes / days).round();
    final prevAvg = (prevMinutes / prevDays).round();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Sessions',
            '$totalSessions',
            Icons.play_circle,
            delta: totalSessions - prevSessions,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Minutes',
            '$totalMinutes',
            Icons.timer,
            delta: totalMinutes - prevMinutes,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Avg min/Day',
            '$avg',
            Icons.trending_up,
            delta: avg - prevAvg,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    int? delta,
  }) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final deltaText = delta == null
        ? null
        : delta == 0
            ? '0'
            : delta > 0
                ? '+$delta'
                : '$delta';

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
            if (deltaText != null)
              Text(
                deltaText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: AppColorPalette.fontSizeSmall,
                  color: secondary,
                  fontWeight: FontWeight.w600,
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
    final labels = _resolveProjectLabels(sessions);
    final data = buildStackedChart(
      period: _selectedPeriod,
      now: DateTime.now(),
      timestamps: sessions.map((s) => s.startTime),
      groupIdAt: (i) => sessions[i].project_id,
      groupLabelAt: (i) {
        final id = sessions[i].project_id;
        if (id == null) return sessions[i].project_name;
        return labels[id] ?? sessions[i].project_name;
      },
      valueAt: (i) => sessions[i].minutesSpent.toDouble(),
    );

    return StackedPeriodBarChart(
      title: 'Focus Sessions Over Time',
      data: data,
      emptyMessage: 'No focus data for this period',
    );
  }

  Map<String, String> _resolveProjectLabels(List<PomodoroModel> sessions) {
    final labels = <String, String>{};
    if (Hive.isBoxOpen('projects')) {
      for (final p in Hive.box<ProjectModel>('projects').values) {
        if (p.name.isNotEmpty) labels[p.id] = p.name;
      }
    }
    for (final s in sessions) {
      final id = s.project_id;
      if (id != null && !labels.containsKey(id) && s.project_name != null) {
        labels[id] = s.project_name!;
      }
    }
    return labels;
  }

  Widget _buildProjectBreakdown(List<PomodoroModel> sessions) {
    final labels = _resolveProjectLabels(sessions);
    final chart = buildStackedChart(
      period: _selectedPeriod,
      now: DateTime.now(),
      timestamps: sessions.map((s) => s.startTime),
      groupIdAt: (i) => sessions[i].project_id,
      groupLabelAt: (i) {
        final id = sessions[i].project_id;
        if (id == null) return sessions[i].project_name;
        return labels[id] ?? sessions[i].project_name;
      },
      valueAt: (_) => 1,
    );

    final projectStats = <String, int>{};
    for (final session in sessions) {
      final id = session.project_id ?? StatsSeriesId.def;
      projectStats[id] = (projectStats[id] ?? 0) + 1;
    }

    final colorById = chart.colorById;
    final ordered = chart.series
        .where((s) => (projectStats[s.id] ?? 0) > 0)
        .toList();
    // Include any groups not in the top series (shouldn't happen often).
    for (final id in projectStats.keys) {
      if (!ordered.any((s) => s.id == id)) {
        ordered.add(
          StatsSeriesMeta(
            id: id,
            label: labels[id] ??
                (id == StatsSeriesId.def ? 'Default' : id),
            color: colorById[id] ?? AppColorPalette.grey500,
          ),
        );
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
            ordered.isEmpty
                ? Text(
                    'No project data available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  )
                : Column(
                    children: ordered.map((series) {
                      final count = projectStats[series.id] ?? 0;
                      return Padding(
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
                                    color: series.color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: AppUiSizes.sm),
                                Text(
                                  series.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontSize: AppColorPalette.fontSizeBody,
                                      ),
                                ),
                              ],
                            ),
                            Text(
                              '$count sessions',
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
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfo(List<PomodoroModel> sessions) {
    final stats = computeStreakStats(
      period: _selectedPeriod,
      activityTimes: sessions.map((s) => s.startTime),
    );

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
                Expanded(
                  child: _buildStreakMetric(
                    stats.current,
                    'Current',
                    stats.unitLabel,
                    highlight: stats.current > 0,
                  ),
                ),
                Expanded(
                  child: _buildStreakMetric(
                    stats.maxAllTime,
                    'Max',
                    stats.unitLabel,
                  ),
                ),
                Expanded(
                  child: _buildStreakMetric(
                    stats.maxThisYear,
                    'Max this year',
                    stats.unitLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutStreakInfo(List<WorkoutSessionModel> sessions) {
    final completed = sessions.where((s) => s.isCompleted);
    final stats = computeStreakStats(
      period: _selectedPeriod,
      activityTimes: completed.map((s) => s.startTime),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Streak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            Row(
              children: [
                Expanded(
                  child: _buildStreakMetric(
                    stats.current,
                    'Current',
                    stats.unitLabel,
                    highlight: stats.current > 0,
                  ),
                ),
                Expanded(
                  child: _buildStreakMetric(
                    stats.maxAllTime,
                    'Max',
                    stats.unitLabel,
                  ),
                ),
                Expanded(
                  child: _buildStreakMetric(
                    stats.maxThisYear,
                    'Max this year',
                    stats.unitLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakMetric(
    int value,
    String label,
    String unit, {
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          Icons.local_fire_department,
          color: highlight
              ? scheme.tertiary
              : scheme.onSurface.withValues(alpha: 0.45),
          size: 28,
        ),
        const SizedBox(height: AppUiSizes.xs),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: AppColorPalette.fontSizeTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutStats(
    List<WorkoutSessionModel> sessions,
    List<WorkoutSessionModel> previous,
  ) {
    final completed = sessions.where((s) => s.isCompleted).toList();
    final prevCompleted = previous.where((s) => s.isCompleted).toList();
    final totalMinutes = completed.fold<int>(
      0,
      (sum, s) => sum + s.durationMinutes,
    );
    final prevMinutes = prevCompleted.fold<int>(
      0,
      (sum, s) => sum + s.durationMinutes,
    );
    final programs = completed
        .map((s) => workoutSetGroupId(s.additionalData, s.routineId))
        .whereType<String>()
        .toSet()
        .length;
    final prevPrograms = prevCompleted
        .map((s) => workoutSetGroupId(s.additionalData, s.routineId))
        .whereType<String>()
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Workouts',
            '${completed.length}',
            Icons.fitness_center,
            delta: completed.length - prevCompleted.length,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Minutes',
            '$totalMinutes',
            Icons.schedule,
            delta: totalMinutes - prevMinutes,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Sets',
            '$programs',
            Icons.list_alt,
            delta: programs - prevPrograms,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutChart(List<WorkoutSessionModel> sessions) {
    final completed = sessions.where((s) => s.isCompleted).toList();
    final setNames = _resolveSetTypeLabels(completed);
    final data = buildStackedChart(
      period: _selectedPeriod,
      now: DateTime.now(),
      timestamps: completed.map((s) => s.startTime),
      groupIdAt: (i) => workoutSetGroupId(
        completed[i].additionalData,
        completed[i].routineId,
      ),
      groupLabelAt: (i) {
        final id = workoutSetGroupId(
          completed[i].additionalData,
          completed[i].routineId,
        );
        if (id == null) return completed[i].routineName;
        return setNames[id] ?? completed[i].routineName;
      },
      valueAt: (_) => 1,
    );

    return StackedPeriodBarChart(
      title: 'Workouts Over Time',
      data: data,
      emptyMessage: 'No workout data yet. Start your first workout!',
    );
  }

  Map<String, String> _resolveSetTypeLabels(
    List<WorkoutSessionModel> sessions,
  ) {
    final labels = <String, String>{};
    if (Hive.isBoxOpen('workoutSetCategories')) {
      for (final s
          in Hive.box<WorkoutSetCategoryModel>('workoutSetCategories').values) {
        if (s.name.isNotEmpty) labels[s.id] = s.name;
      }
    }
    for (final session in sessions) {
      final id = workoutSetGroupId(session.additionalData, session.routineId);
      if (id != null && !labels.containsKey(id)) {
        labels[id] = session.routineName;
      }
    }
    return labels;
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

  List<PomodoroModel> _filterSessionsByPreviousPeriod(
    List<PomodoroModel> sessions,
  ) {
    final range = StatsPeriodRange.previousPeriod(_selectedPeriod);
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

  List<WorkoutSessionModel> _filterWorkoutsByPreviousPeriod(
    List<WorkoutSessionModel> sessions,
  ) {
    final range = StatsPeriodRange.previousPeriod(_selectedPeriod);
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

    final acquired =
        inPeriod.where((c) {
          if (effectiveFilter == kCollectibleBookmarkFilter) {
            return c.isBookmarked;
          }
          if (effectiveFilter != 'all' && c.typeWire != effectiveFilter) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
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

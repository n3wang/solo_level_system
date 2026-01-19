// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/habit_tracker_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';

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
            Tab(text: 'Features'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Time period selector below tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedPeriod),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down),
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
                _buildFeaturesTab(),
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
                    final pomodoros = _filterSessionsByPeriod(
                      pomodoroBox.values.toList(),
                    );
                    final workouts = _filterWorkoutsByPeriod(
                      workoutBox.values.toList(),
                    );
                    final habits = habitBox.values
                        .where((h) => h.isActive)
                        .toList();

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickStats(pomodoros, workouts, habits),
                          // SizedBox(height: 24),
                          // _buildProductivityScore(pomodoros, workouts, habits),
                          SizedBox(height: 24),
                          _buildWeeklyOverview(pomodoros),
                          SizedBox(height: 24),
                          _buildGoalsProgress(pomodoros, workouts, habits),
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
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFocusStats(filteredSessions),
                  SizedBox(height: 24),
                  _buildFocusChart(filteredSessions),
                  SizedBox(height: 24),
                  _buildProjectBreakdown(filteredSessions),
                  SizedBox(height: 24),
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
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkoutStats(filteredSessions),
                  SizedBox(height: 24),
                  _buildWorkoutChart(filteredSessions),
                  SizedBox(height: 24),
                  _buildPersonalRecords(filteredSessions),
                  SizedBox(height: 24),
                  _buildMuscleGroupBreakdown(filteredSessions),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeaturesTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<UserProgressModel>('userProgress'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading progress data: ${snapshot.error}'),
          );
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<UserProgressModel>(
            'userProgress',
          ).listenable(),
          builder: (context, box, _) {
            final userProgress = box.get('progress');

            if (userProgress == null) {
              return Center(child: Text('No progress data available'));
            }

            final featureRequirements =
                ProgressConstants.FEATURE_UNLOCK_REQUIREMENTS;
            final featureDescriptions = ProgressConstants.FEATURE_DESCRIPTIONS;

            return ListView(
              padding: EdgeInsets.all(16),
              children: featureRequirements.entries.map((entry) {
                final isUnlocked =
                    userProgress.canUnlockFeature(entry.key, entry.value) ||
                    userProgress.isFeatureUnlocked(entry.key);
                final canUnlock = userProgress.canUnlockFeature(
                  entry.key,
                  entry.value,
                );

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isUnlocked ? Icons.lock_open : Icons.lock,
                      color: isUnlocked ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featureDescriptions[entry.key] ??
                              'Feature description',
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Requires ${entry.value} XP',
                          style: TextStyle(
                            color: isUnlocked ? Colors.green : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: isUnlocked
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : canUnlock
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                _unlockFeature(entry.key, userProgress),
                            child: Text('Unlock'),
                          )
                        : Text(
                            '${entry.value - userProgress.totalExperience} XP needed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _unlockFeature(String featureId, UserProgressModel userProgress) {
    userProgress.unlockFeature(featureId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Feature unlocked! Check the app for new options.'),
        backgroundColor: Colors.green,
      ),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats - $_selectedPeriod',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
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
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week - Focus Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
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
                              ? Colors.grey[300]
                              : Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        sessions.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(dayNames[index], style: TextStyle(fontSize: 12)),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goals Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
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

  Widget _buildGoalItem(String goal, int current, int target) {
    final progress = current / target;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(goal), Text('$current/$target')],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusChart(List<PomodoroModel> sessions) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Sessions Over Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            projectStats.isEmpty
                ? Text(
                    'No project data available',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : Column(
                    children: projectStats.entries
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
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
                                    SizedBox(width: 8),
                                    Text(
                                      projectNames[entry.key] ?? 'Unknown',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${entry.value} sessions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
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
    // Simple color assignment based on project ID
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    if (projectId == 'unassigned') return Colors.grey;

    final hash = projectId.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildStreakInfo(List<PomodoroModel> sessions) {
    int currentStreak = _calculateCurrentStreak(sessions);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Streak',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: currentStreak > 0 ? Colors.orange : Colors.grey,
                  size: 32,
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStreak > 0 ? '$currentStreak days' : 'No streak',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Current streak',
                      style: TextStyle(color: Colors.grey[600]),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Frequency',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            sessions.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'No workout data yet. Start your first workout!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        '${sessions.length} total sessions recorded',
                        style: TextStyle(
                          fontSize: 16,
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            recordSessions.isEmpty
                ? Text(
                    'No personal records set yet. Keep pushing!',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : Column(
                    children: [
                      Text(
                        '🏆 ${recordSessions.fold<int>(0, (sum, s) => sum + s.personalRecordsSet.length)} records set',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Across ${recordSessions.length} sessions',
                        style: TextStyle(color: Colors.grey[600]),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Locations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            locations.isEmpty
                ? Text(
                    'No location data available',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : Column(
                    children: locations.entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
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

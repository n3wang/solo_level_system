// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/habit_tracker_model.dart';

class AnalyticsScreen extends StatefulWidget {
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
        title: Text('Analytics & Insights'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (period) {
              setState(() => _selectedPeriod = period);
            },
            itemBuilder: (context) => _periods
                .map(
                  (period) => PopupMenuItem(value: period, child: Text(period)),
                )
                .toList(),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_selectedPeriod), Icon(Icons.arrow_drop_down)],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.timer), text: 'Focus'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
            Tab(icon: Icon(Icons.track_changes), text: 'Habits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildFocusTab(),
          _buildWorkoutsTab(),
          _buildHabitsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStats(),
          SizedBox(height: 24),
          _buildProductivityScore(),
          SizedBox(height: 24),
          _buildWeeklyOverview(),
          SizedBox(height: 24),
          _buildGoalsProgress(),
        ],
      ),
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
          return Center(child: Text('Error loading focus data: ${snapshot.error}'));
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
                  _buildStreakInfo(),
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
          return Center(child: Text('Error loading workout data: ${snapshot.error}'));
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<WorkoutSessionModel>('workoutSessions').listenable(),
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
                  _buildPersonalRecords(),
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

  Widget _buildHabitsTab() {
    return FutureBuilder(
      future: _ensureBoxIsOpen<HabitTrackerModel>('habits'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading habits data: ${snapshot.error}'));
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<HabitTrackerModel>('habits').listenable(),
          builder: (context, Box<HabitTrackerModel> box, _) {
            final habits = box.values.where((h) => h.isActive).toList();

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHabitsOverview(habits),
                  SizedBox(height: 24),
                  _buildHabitsGrid(habits),
                  SizedBox(height: 24),
                  _buildStreaksLeaderboard(habits),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Focus Sessions', '12', Icons.timer),
                ),
                Expanded(
                  child: _buildStatItem('Workouts', '4', Icons.fitness_center),
                ),
                Expanded(
                  child: _buildStatItem('Habits', '8/10', Icons.track_changes),
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

  Widget _buildProductivityScore() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productivity Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        value: 0.75,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '75/100',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScoreBreakdown('Focus', 0.8, Colors.blue),
                      _buildScoreBreakdown('Exercise', 0.7, Colors.orange),
                      _buildScoreBreakdown('Habits', 0.75, Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown(String label, double value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(width: 8),
          Text('${(value * 100).round()}%', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
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
                  final heights = [0.8, 0.6, 0.9, 0.4, 0.7, 0.3, 0.5];

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: heights[index] * 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 8),
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

  Widget _buildGoalsProgress() {
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
            _buildGoalItem('Daily Focus Sessions', 3, 5),
            _buildGoalItem('Weekly Workouts', 2, 4),
            _buildGoalItem('Habit Completion', 8, 10),
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
            '${avgPerDay.toStringAsFixed(1)}',
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
            Container(
              height: 200,
              child: Center(child: Text('Chart would go here')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectBreakdown(List<PomodoroModel> sessions) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects Focus Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Implementation would show project breakdown
            Text('Project breakdown chart would go here'),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfo() {
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
                  color: Colors.orange,
                  size: 32,
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7 days',
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

  Widget _buildWorkoutStats(List<WorkoutSessionModel> sessions) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Workouts',
            '${sessions.length}',
            Icons.fitness_center,
          ),
        ),
        Expanded(child: _buildStatCard('Hours', '0', Icons.schedule)),
        Expanded(
          child: _buildStatCard('Calories', '0', Icons.local_fire_department),
        ),
      ],
    );
  }

  Widget _buildWorkoutChart(List<WorkoutSessionModel> sessions) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Workout chart placeholder'),
      ),
    );
  }

  Widget _buildPersonalRecords() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Personal records placeholder'),
      ),
    );
  }

  Widget _buildMuscleGroupBreakdown(List<WorkoutSessionModel> sessions) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Muscle group breakdown placeholder'),
      ),
    );
  }

  Widget _buildHabitsOverview(List<HabitTrackerModel> habits) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Habits overview placeholder'),
      ),
    );
  }

  Widget _buildHabitsGrid(List<HabitTrackerModel> habits) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Habits grid placeholder'),
      ),
    );
  }

  Widget _buildStreaksLeaderboard(List<HabitTrackerModel> habits) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Streaks leaderboard placeholder'),
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

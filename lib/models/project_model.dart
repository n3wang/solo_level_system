// lib/models/project_model.dart
import 'package:hive/hive.dart';
part 'project_model.g.dart';

@HiveType(typeId: 20)
class ProjectModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String color; // Hex color code

  @HiveField(4)
  String? iconName; // Icon identifier

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? archivedAt;

  @HiveField(8)
  List<String> habitIds; // Associated habit tracker IDs

  @HiveField(9)
  Map<int, int> weeklyPomodoroTargets; // weekday (1-7) -> pomodoro count

  @HiveField(10)
  List<int> activeDays; // weekdays when this project is active (1=Monday, 7=Sunday)

  @HiveField(11)
  int totalCompletedPomodoros;

  @HiveField(12)
  DateTime? lastWorkedOn;

  @HiveField(13)
  Map<String, int> dailyStats; // date (YYYY-MM-DD) -> pomodoro count

  @HiveField(14)
  int priority; // 1-6 for ordering (1 = highest priority)

  @HiveField(15)
  String? notes;

  @HiveField(16)
  List<String> tags;

  @HiveField(17)
  String targetType; // 'daily' or 'weekly'

  @HiveField(18)
  int dailySessionTarget; // Target sessions per day

  @HiveField(19)
  int weeklySessionTarget; // Target sessions per week

  @HiveField(20)
  int? preferredWorkHour; // Preferred work hour (0-23), null if no preference

  ProjectModel({
    required this.id,
    required this.name,
    this.description,
    this.color = '#4CAF50', // Default green
    this.iconName,
    this.isActive = true,
    required this.createdAt,
    this.archivedAt,
    this.habitIds = const [],
    this.weeklyPomodoroTargets = const {},
    this.activeDays = const [1, 2, 3, 4, 5], // Mon-Fri by default
    this.totalCompletedPomodoros = 0,
    this.lastWorkedOn,
    this.dailyStats = const {},
    this.priority = 1,
    this.notes,
    this.tags = const [],
    this.targetType = 'daily',
    this.dailySessionTarget = 2,
    this.weeklySessionTarget = 10,
    this.preferredWorkHour,
  });

  // Convenience getters
  String get shortName {
    if (name.length <= 8) return name;
    return name.substring(0, 7) + '…';
  }

  bool get isActiveToday {
    final today = DateTime.now().weekday;
    return isActive && activeDays.contains(today);
  }

  int get todayTarget {
    if (targetType == 'daily') {
      return dailySessionTarget;
    } else {
      // For weekly targets, distribute across active days
      final activeDaysThisWeek = activeDays.length;
      return activeDaysThisWeek > 0
          ? (weeklySessionTarget / activeDaysThisWeek).ceil()
          : 0;
    }
  }

  int get todayCompleted {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return dailyStats[dateKey] ?? 0;
  }

  double get todayProgress {
    final target = todayTarget;
    if (target == 0) return 0.0;
    return (todayCompleted / target).clamp(0.0, 1.0);
  }

  bool get isTodayComplete {
    return todayCompleted >= todayTarget;
  }

  String get progressText {
    return '${todayCompleted}/${todayTarget}';
  }

  int get weeklyTarget {
    return weeklyPomodoroTargets.values.fold(0, (sum, target) => sum + target);
  }

  int get weeklyCompleted {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int weeklyCount = 0;

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final dateKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      weeklyCount += dailyStats[dateKey] ?? 0;
    }

    return weeklyCount;
  }

  double get weeklyProgress {
    if (weeklyTarget == 0) return 0.0;
    return (weeklyCompleted / weeklyTarget).clamp(0.0, 1.0);
  }

  String get statusText {
    if (!isActive) return 'Archived';
    if (!isActiveToday) return 'Not scheduled today';
    if (isTodayComplete) return 'Complete ✓';
    return 'In progress';
  }

  // Methods
  void addPomodoroSession({DateTime? date}) {
    final sessionDate = date ?? DateTime.now();
    final dateKey =
        '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';

    dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + 1;
    totalCompletedPomodoros++;
    lastWorkedOn = sessionDate;

    save();
  }

  void setWeeklyTarget(int weekday, int pomodoroCount) {
    if (weekday >= 1 && weekday <= 7 && pomodoroCount >= 0) {
      weeklyPomodoroTargets[weekday] = pomodoroCount;
      save();
    }
  }

  void updateActiveDays(List<int> days) {
    activeDays = days.where((day) => day >= 1 && day <= 7).toList();
    save();
  }

  void addHabit(String habitId) {
    if (!habitIds.contains(habitId)) {
      habitIds.add(habitId);
      save();
    }
  }

  void removeHabit(String habitId) {
    habitIds.remove(habitId);
    save();
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      save();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    save();
  }

  void archive() {
    isActive = false;
    archivedAt = DateTime.now();
    save();
  }

  void unarchive() {
    isActive = true;
    archivedAt = null;
    save();
  }

  void updateNotes(String newNotes) {
    notes = newNotes;
    save();
  }

  void updatePriority(int newPriority) {
    if (newPriority >= 1 && newPriority <= 6) {
      priority = newPriority;
      save();
    }
  }

  // Get pomodoro count for a specific date range
  int getPomodoroCountForPeriod(DateTime startDate, DateTime endDate) {
    int count = 0;
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      final dateKey =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      count += dailyStats[dateKey] ?? 0;
      current = current.add(Duration(days: 1));
    }

    return count;
  }

  // Get completion rate for the current week
  double getWeekCompletionRate() {
    if (weeklyTarget == 0) return 0.0;
    return weeklyProgress;
  }

  // Check if project should be worked on today based on schedule
  bool shouldWorkOnToday() {
    return isActiveToday && todayTarget > 0;
  }

  // Get remaining pomodoros needed today
  int getRemainingTodayPomodoros() {
    return (todayTarget - todayCompleted).clamp(0, todayTarget);
  }

  @override
  String toString() {
    return 'ProjectModel(id: $id, name: $name, todayProgress: ${progressText})';
  }
}

// Helper class for project creation
class ProjectCreationHelper {
  static const List<String> defaultColors = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FF9800', // Orange
    '#9C27B0', // Purple
    '#F44336', // Red
    '#795548', // Brown
  ];

  static const List<String> defaultIcons = [
    'work',
    'school',
    'fitness_center',
    'palette',
    'code',
    'music_note',
  ];

  static ProjectModel createDefault({
    required String name,
    String? description,
    int priority = 1,
  }) {
    final colorIndex = (priority - 1) % defaultColors.length;
    final iconIndex = (priority - 1) % defaultIcons.length;

    return ProjectModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      color: defaultColors[colorIndex],
      iconName: defaultIcons[iconIndex],
      createdAt: DateTime.now(),
      priority: priority,
      activeDays: [1, 2, 3, 4, 5], // Monday to Friday
      weeklyPomodoroTargets: {
        1: 2, // Monday
        2: 2, // Tuesday
        3: 2, // Wednesday
        4: 2, // Thursday
        5: 2, // Friday
      },
    );
  }
}

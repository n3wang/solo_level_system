// lib/models/habit_tracker_model.dart
import 'package:hive/hive.dart';
part 'habit_tracker_model.g.dart';

@HiveType(typeId: 8)
class HabitTrackerModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String type; // 'pomodoro', 'workout', 'custom'

  @HiveField(4)
  String? targetId; // routine ID for workouts, null for pomodoros

  @HiveField(5)
  String frequency; // 'daily', 'weekly', 'custom'

  @HiveField(6)
  int targetCount; // How many times per frequency period

  @HiveField(7)
  List<DateTime> completedDates;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? archivedAt;

  @HiveField(10)
  bool isActive;

  @HiveField(11)
  String? iconName; // Icon identifier

  @HiveField(12)
  String? color; // Color hex code

  @HiveField(13)
  List<String> tags;

  @HiveField(14)
  Map<String, int> weeklyStats; // week_year -> completion count

  @HiveField(15)
  int currentStreak;

  @HiveField(16)
  int longestStreak;

  @HiveField(17)
  DateTime? lastCompletedAt;

  @HiveField(18)
  List<String> notes; // Daily notes indexed by date

  HabitTrackerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.targetId,
    this.frequency = 'daily',
    this.targetCount = 1,
    this.completedDates = const [],
    required this.createdAt,
    this.archivedAt,
    this.isActive = true,
    this.iconName,
    this.color,
    this.tags = const [],
    this.weeklyStats = const {},
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedAt,
    this.notes = const [],
  });

  // Convenience getters
  bool get isCompleted => _isCompletedToday();

  int get todayCompletionCount => _getTodayCompletionCount();

  double get todayProgress => targetCount > 0
      ? (todayCompletionCount / targetCount).clamp(0.0, 1.0)
      : 0.0;

  bool get isArchived => archivedAt != null;

  String get streakText {
    if (currentStreak == 0) return 'No streak';
    if (currentStreak == 1) return '1 day streak';
    return '$currentStreak days streak';
  }

  String get completionRate {
    if (completedDates.isEmpty) return '0%';
    final daysActive = DateTime.now().difference(createdAt).inDays + 1;
    final completionDays = _getUniqueDaysCompleted();
    final rate = (completionDays / daysActive * 100).round();
    return '$rate%';
  }

  // Methods
  void markCompleted({DateTime? date}) {
    final completionDate = date ?? DateTime.now();
    final dateOnly = DateTime(
      completionDate.year,
      completionDate.month,
      completionDate.day,
    );

    completedDates.add(completionDate);
    lastCompletedAt = completionDate;

    _updateStreaks();
    _updateWeeklyStats(dateOnly);

    save();
  }

  void markUncompleted({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final dateOnly = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    // Remove all completions for this date
    completedDates.removeWhere((d) => _isSameDay(d, dateOnly));

    _updateStreaks();
    _updateWeeklyStats(dateOnly);

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

  void addNote(String note, {DateTime? date}) {
    final noteDate = date ?? DateTime.now();
    final dateKey = '${noteDate.year}-${noteDate.month}-${noteDate.day}';
    notes.add('$dateKey: $note');
    save();
  }

  List<DateTime> getCompletionsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return completedDates.where((d) => _isSameDay(d, dateOnly)).toList();
  }

  int getCompletionCountForDate(DateTime date) {
    return getCompletionsForDate(date).length;
  }

  List<DateTime> getWeekCompletions() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));

    return completedDates
        .where(
          (date) =>
              date.isAfter(weekStart.subtract(Duration(days: 1))) &&
              date.isBefore(weekEnd.add(Duration(days: 1))),
        )
        .toList();
  }

  Map<int, int> getMonthlyCompletions(int year, int month) {
    final monthCompletions = <int, int>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      monthCompletions[day] = getCompletionCountForDate(date);
    }

    return monthCompletions;
  }

  // Private helper methods
  bool _isCompletedToday() {
    return _getTodayCompletionCount() >= targetCount;
  }

  int _getTodayCompletionCount() {
    final today = DateTime.now();
    return getCompletionCountForDate(today);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  int _getUniqueDaysCompleted() {
    final uniqueDays = <String>{};
    for (final date in completedDates) {
      uniqueDays.add('${date.year}-${date.month}-${date.day}');
    }
    return uniqueDays.length;
  }

  void _updateStreaks() {
    currentStreak = _calculateCurrentStreak();
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
  }

  int _calculateCurrentStreak() {
    if (completedDates.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      // Check up to a year back
      final checkDate = today.subtract(Duration(days: i));
      final completions = getCompletionCountForDate(checkDate);

      if (completions >= targetCount) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  void _updateWeeklyStats(DateTime date) {
    final weekYear = '${_getWeekOfYear(date)}_${date.year}';
    weeklyStats[weekYear] = (weeklyStats[weekYear] ?? 0) + 1;
  }

  int _getWeekOfYear(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}

// lib/models/user_progress_model.dart
import 'package:hive/hive.dart';
part 'user_progress_model.g.dart';

@HiveType(typeId: 21)
class UserProgressModel extends HiveObject {
  @HiveField(0)
  int totalExperience;

  @HiveField(1)
  int availablePoints;

  @HiveField(2)
  int totalPointsEarned;

  @HiveField(3)
  int totalPointsSpent;

  @HiveField(4)
  int currentLevel;

  @HiveField(5)
  int totalPomodoroSessions;

  @HiveField(6)
  DateTime? lastSessionDate;

  @HiveField(7)
  int currentStreak;

  @HiveField(8)
  int longestStreak;

  @HiveField(9)
  Map<String, int> dailySessionCount; // date -> session count

  @HiveField(10)
  Map<String, int> weeklyStats; // week_year -> sessions

  @HiveField(11)
  List<String> unlockedFeatures;

  @HiveField(12)
  Map<String, int> milestoneProgress; // milestone_id -> current progress

  UserProgressModel({
    this.totalExperience = 0,
    this.availablePoints = 0,
    this.totalPointsEarned = 0,
    this.totalPointsSpent = 0,
    this.currentLevel = 1,
    this.totalPomodoroSessions = 0,
    this.lastSessionDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.dailySessionCount = const {},
    this.weeklyStats = const {},
    this.unlockedFeatures = const [],
    this.milestoneProgress = const {},
  });

  // Constants - now per minute instead of per session
  static const int POINTS_PER_MINUTE = 1;
  static const int XP_PER_MINUTE = 1;
  static const int XP_PER_LEVEL = 100;
  static const int BONUS_STREAK_MULTIPLIER = 5; // Every 5 days adds +5 bonus XP

  // Computed properties
  int get experienceForCurrentLevel {
    return currentLevel * XP_PER_LEVEL;
  }

  int get experienceForNextLevel {
    return (currentLevel + 1) * XP_PER_LEVEL;
  }

  int get experienceInCurrentLevel {
    return totalExperience - experienceForCurrentLevel;
  }

  int get experienceNeededForNextLevel {
    return experienceForNextLevel - totalExperience;
  }

  double get progressToNextLevel {
    if (experienceNeededForNextLevel <= 0) return 1.0;
    return (experienceInCurrentLevel / XP_PER_LEVEL).clamp(0.0, 1.0);
  }

  String get levelTitle {
    if (currentLevel < 5) return 'Beginner Focuser';
    if (currentLevel < 10) return 'Focused Student';
    if (currentLevel < 20) return 'Concentration Expert';
    if (currentLevel < 35) return 'Productivity Master';
    if (currentLevel < 50) return 'Focus Virtuoso';
    return 'Zen Master';
  }

  String get nextMilestone {
    if (totalPomodoroSessions < 10) return '10 Sessions';
    if (totalPomodoroSessions < 50) return '50 Sessions';
    if (totalPomodoroSessions < 100) return '100 Sessions';
    if (totalPomodoroSessions < 250) return '250 Sessions';
    if (totalPomodoroSessions < 500) return '500 Sessions';
    if (totalPomodoroSessions < 1000) return '1000 Sessions';
    return 'Session Master';
  }

  // Methods
  void completePomodoro({DateTime? sessionDate, int? streakMultiplier, int minutesSpent = 25}) {
    final date = sessionDate ?? DateTime.now();
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Update session counts
    totalPomodoroSessions++;
    dailySessionCount[dateKey] = (dailySessionCount[dateKey] ?? 0) + 1;

    // Update streak
    _updateStreak(date);

    // Calculate rewards based on minutes spent
    int baseXP = minutesSpent * XP_PER_MINUTE;
    int basePoints = minutesSpent * POINTS_PER_MINUTE;

    // Streak bonus (every 5 days of streak adds 5 bonus XP)
    int streakBonus = (currentStreak ~/ BONUS_STREAK_MULTIPLIER) * 5;

    // Level bonus (higher levels get slight bonus)
    int levelBonus = currentLevel ~/ 10;

    final totalXP = baseXP + streakBonus + levelBonus;
    final totalPoints = basePoints;

    // Add rewards
    addExperience(totalXP);
    addPoints(totalPoints);

    lastSessionDate = date;
    save();

    print('Pomodoro completed! +$totalXP XP ($minutesSpent minutes + $streakBonus streak + $levelBonus level), +$totalPoints points ($minutesSpent minutes)');
  }

  void addExperience(int xp) {
    totalExperience += xp;
    _checkLevelUp();
  }

  void addPoints(int points) {
    availablePoints += points;
    totalPointsEarned += points;
  }

  bool spendPoints(int points) {
    if (availablePoints >= points) {
      availablePoints -= points;
      totalPointsSpent += points;
      save();
      return true;
    }
    return false;
  }

  void unlockFeature(String featureId) {
    if (!unlockedFeatures.contains(featureId)) {
      unlockedFeatures.add(featureId);
      save();
    }
  }

  bool isFeatureUnlocked(String featureId) {
    return unlockedFeatures.contains(featureId);
  }

  bool canUnlockFeature(String featureId, int requiredXP) {
    return totalExperience >= requiredXP && !isFeatureUnlocked(featureId);
  }

  void _updateStreak(DateTime sessionDate) {
    if (lastSessionDate == null) {
      currentStreak = 1;
    } else {
      final daysDifference = sessionDate.difference(lastSessionDate!).inDays;

      if (daysDifference == 1) {
        // Consecutive day
        currentStreak++;
      } else if (daysDifference == 0) {
        // Same day, maintain streak
        // Do nothing
      } else {
        // Streak broken
        currentStreak = 1;
      }
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
  }

  void _checkLevelUp() {
    int newLevel = 1;
    int totalXPNeeded = 0;

    // Calculate what level we should be at
    while (totalXPNeeded + ((newLevel + 1) * XP_PER_LEVEL) <= totalExperience) {
      newLevel++;
      totalXPNeeded += newLevel * XP_PER_LEVEL;
    }

    if (newLevel > currentLevel) {
      final levelsGained = newLevel - currentLevel;
      currentLevel = newLevel;

      print('🎉 LEVEL UP! You are now level $currentLevel ($levelTitle)');

      // Bonus points for leveling up
      final bonusPoints = levelsGained * 50;
      availablePoints += bonusPoints;
      totalPointsEarned += bonusPoints;

      print('Level up bonus: +$bonusPoints points!');

      save();
    }
  }

  // Statistics methods
  int getSessionsToday() {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return dailySessionCount[dateKey] ?? 0;
  }

  int getSessionsThisWeek() {
    final now = DateTime.now();
    int count = 0;

    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: now.weekday - 1 - i));
      final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      count += dailySessionCount[dateKey] ?? 0;
    }

    return count;
  }

  List<int> getWeeklySessionData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return dailySessionCount[dateKey] ?? 0;
    });
  }

  // Reset methods (for testing or new starts)
  void resetProgress() {
    totalExperience = 0;
    availablePoints = 0;
    totalPointsEarned = 0;
    totalPointsSpent = 0;
    currentLevel = 1;
    totalPomodoroSessions = 0;
    lastSessionDate = null;
    currentStreak = 0;
    longestStreak = 0;
    dailySessionCount.clear();
    weeklyStats.clear();
    unlockedFeatures.clear();
    milestoneProgress.clear();
    save();
  }

  @override
  String toString() {
    return 'UserProgress(Level: $currentLevel, XP: $totalExperience, Points: $availablePoints, Sessions: $totalPomodoroSessions, Streak: $currentStreak)';
  }
}

// Helper class for level and milestone definitions
class ProgressConstants {
  static const Map<String, int> FEATURE_UNLOCK_REQUIREMENTS = {
    'advanced_analytics': 250,      // Level ~3
    'custom_themes': 500,          // Level ~5
    'project_templates': 750,      // Level ~8
    'habit_automation': 1000,      // Level ~10
    'advanced_statistics': 1500,   // Level ~15
    'export_data': 2000,          // Level ~20
    'custom_sounds': 2500,        // Level ~25
    'focus_modes': 3000,          // Level ~30
    'team_features': 5000,        // Level ~50
  };

  static const Map<String, String> FEATURE_DESCRIPTIONS = {
    'advanced_analytics': 'Unlock detailed analytics with charts and trends',
    'custom_themes': 'Access to custom color themes and appearance options',
    'project_templates': 'Create and save project templates for quick setup',
    'habit_automation': 'Automatically link habits to projects and schedules',
    'advanced_statistics': 'Get deep insights with advanced statistical analysis',
    'export_data': 'Export your data to various formats (CSV, JSON, PDF)',
    'custom_sounds': 'Upload and use custom notification sounds',
    'focus_modes': 'Access specialized focus modes and ambient sounds',
    'team_features': 'Collaborate with others and share progress',
  };

  static const List<Map<String, dynamic>> MILESTONES = [
    {'sessions': 10, 'title': 'First Steps', 'points_bonus': 100},
    {'sessions': 25, 'title': 'Getting Started', 'points_bonus': 200},
    {'sessions': 50, 'title': 'Focused Learner', 'points_bonus': 500},
    {'sessions': 100, 'title': 'Productivity Seeker', 'points_bonus': 1000},
    {'sessions': 250, 'title': 'Focus Expert', 'points_bonus': 2000},
    {'sessions': 500, 'title': 'Concentration Master', 'points_bonus': 5000},
    {'sessions': 1000, 'title': 'Zen Master', 'points_bonus': 10000},
  ];
}
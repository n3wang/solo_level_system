// lib/models/user_progress_model.dart
import 'package:hive/hive.dart';
import 'package:solo_level_system/utils/motivation_points_service.dart';
part 'user_progress_model.g.dart';

/// Player wallet + session stats.
///
/// Progression is **points + collectible cards** only — there is no level or
/// XP track. The legacy XP / level / milestone / feature fields below are
/// retained only so existing Hive records still read; they are no longer
/// written or surfaced. Rewards for completing a session are granted by
/// `SessionRewardService`, and feature/content gating is handled by
/// `UnlockService` (cards), not by this model.
@HiveType(typeId: 21)
class UserProgressModel extends HiveObject {
  @Deprecated('XP/levels retired — points + cards only. Kept for Hive compat.')
  @HiveField(0)
  int totalExperience;

  @HiveField(1)
  int availablePoints;

  @HiveField(2)
  int totalPointsEarned;

  @HiveField(3)
  int totalPointsSpent;

  @Deprecated('XP/levels retired — points + cards only. Kept for Hive compat.')
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

  @Deprecated('Feature gating moved to card unlocks. Kept for Hive compat.')
  @HiveField(11)
  List<String> unlockedFeatures;

  @Deprecated('Milestones retired. Kept for Hive compat.')
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

  String get nextMilestone {
    if (totalPomodoroSessions < 10) return '10 Sessions';
    if (totalPomodoroSessions < 50) return '50 Sessions';
    if (totalPomodoroSessions < 100) return '100 Sessions';
    if (totalPomodoroSessions < 250) return '250 Sessions';
    if (totalPomodoroSessions < 500) return '500 Sessions';
    if (totalPomodoroSessions < 1000) return '1000 Sessions';
    return 'Session Master';
  }

  /// Record a completed session's stats (count + streak). Points and card loot
  /// are granted separately by `SessionRewardService`.
  void recordSession({DateTime? sessionDate}) {
    final date = sessionDate ?? DateTime.now();
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    totalPomodoroSessions++;
    dailySessionCount[dateKey] = (dailySessionCount[dateKey] ?? 0) + 1;
    _updateStreak(date);
    lastSessionDate = date;
    save();
  }

  void addPoints(int points) {
    availablePoints += points;
    totalPointsEarned += points;
  }

  bool spendPoints(int points) {
    if (availablePoints >= points) {
      availablePoints -= points;
      totalPointsSpent += points;
      MotivationPointsService.recordSpent(
        amount: points,
        source: 'points_spend',
      );
      save();
      return true;
    }
    return false;
  }

  void _updateStreak(DateTime sessionDate) {
    if (lastSessionDate == null) {
      currentStreak = 1;
    } else {
      final daysDifference = sessionDate.difference(lastSessionDate!).inDays;
      if (daysDifference == 1) {
        currentStreak++;
      } else if (daysDifference == 0) {
        // Same day, maintain streak.
      } else {
        currentStreak = 1;
      }
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
  }

  // Statistics methods
  int getSessionsToday() {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return dailySessionCount[dateKey] ?? 0;
  }

  int getSessionsThisWeek() {
    final now = DateTime.now();
    int count = 0;

    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: now.weekday - 1 - i));
      final dateKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      count += dailySessionCount[dateKey] ?? 0;
    }

    return count;
  }

  List<int> getWeeklySessionData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      final dateKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return dailySessionCount[dateKey] ?? 0;
    });
  }

  // Reset methods (for testing or new starts)
  void resetProgress() {
    availablePoints = 0;
    totalPointsEarned = 0;
    totalPointsSpent = 0;
    totalPomodoroSessions = 0;
    lastSessionDate = null;
    currentStreak = 0;
    longestStreak = 0;
    dailySessionCount.clear();
    weeklyStats.clear();
    save();
  }

  @override
  String toString() {
    return 'UserProgress(Points: $availablePoints, Sessions: $totalPomodoroSessions, Streak: $currentStreak)';
  }
}

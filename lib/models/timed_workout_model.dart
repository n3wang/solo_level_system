// lib/models/timed_workout_model.dart
import 'package:hive/hive.dart';

part 'timed_workout_model.g.dart';

@HiveType(typeId: 24)
class TimedWorkoutItem extends HiveObject {
  @HiveField(0)
  String workoutId; // References ExerciseModel.id

  @HiveField(1)
  int time; // Time in seconds

  @HiveField(2)
  bool useTimed; // If true, use time instead of weight/reps

  TimedWorkoutItem({
    required this.workoutId,
    required this.time,
    this.useTimed = true,
  });
}

@HiveType(typeId: 25)
class TimedWorkoutModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<TimedWorkoutItem> workoutOrder;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? modifiedAt;

  @HiveField(5)
  bool isCustom;

  @HiveField(6)
  String? imageUrl; // Program card image, falls back to first exercise image

  @HiveField(7)
  bool isBookmarked; // Bookmarked programs appear first

  @HiveField(8)
  int timesPerformed; // Number of times this program was completed

  @HiveField(9)
  List<DateTime> completionDates; // Dates when program was completed

  /// Whether this program appears in the Programs tab subscription strip.
  @HiveField(10)
  bool isSubscribed;

  TimedWorkoutModel({
    required this.id,
    required this.name,
    required this.workoutOrder,
    required this.createdAt,
    this.modifiedAt,
    this.isCustom = true,
    this.imageUrl,
    this.isBookmarked = false,
    this.timesPerformed = 0,
    this.completionDates = const [],
    this.isSubscribed = false,
  });

  /// Get total duration in seconds
  int get totalDuration {
    return workoutOrder.fold(0, (sum, item) => sum + item.time);
  }

  /// Get formatted total duration (e.g., "7 min")
  String get formattedDuration {
    final minutes = totalDuration ~/ 60;
    final seconds = totalDuration % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes min $seconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }

  void toggleBookmark() {
    isBookmarked = !isBookmarked;
    save();
  }

  void setSubscribed(bool value) {
    isSubscribed = value;
    save();
  }

  void toggleSubscribed() {
    isSubscribed = !isSubscribed;
    save();
  }

  void recordCompletion() {
    timesPerformed++;
    completionDates.add(DateTime.now());
    // Keep only last 10 completion dates
    if (completionDates.length > 10) {
      completionDates = completionDates.sublist(completionDates.length - 10);
    }
    save();
  }
}

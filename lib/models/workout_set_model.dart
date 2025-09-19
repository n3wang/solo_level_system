// lib/models/workout_set_model.dart
import 'package:hive/hive.dart';
part 'workout_set_model.g.dart';

@HiveType(typeId: 5)
class WorkoutSetModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String exerciseId;

  @HiveField(2)
  int reps;

  @HiveField(3)
  double? weight; // In kg or lbs

  @HiveField(4)
  int? duration; // In seconds for time-based exercises

  @HiveField(5)
  double? distance; // In km or miles for cardio

  @HiveField(6)
  int restTimeSeconds;

  @HiveField(7)
  bool isCompleted;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  int? targetReps; // Planned vs actual

  @HiveField(11)
  double? targetWeight;

  @HiveField(12)
  int? targetDuration;

  @HiveField(13)
  double? targetDistance;

  WorkoutSetModel({
    required this.id,
    required this.exerciseId,
    required this.reps,
    this.weight,
    this.duration,
    this.distance,
    this.restTimeSeconds = 60,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
    this.targetReps,
    this.targetWeight,
    this.targetDuration,
    this.targetDistance,
  });

  // Convenience getters
  String get displayText {
    if (weight != null) {
      return '$reps reps @ ${weight}kg';
    } else if (duration != null) {
      return '${_formatDuration(duration!)}';
    } else if (distance != null) {
      return '${distance}km';
    } else {
      return '$reps reps';
    }
  }

  bool get isPersonalRecord => weight != null; // Simplified for now

  String get restTimeFormatted => _formatDuration(restTimeSeconds);

  // Methods
  void complete() {
    isCompleted = true;
    completedAt = DateTime.now();
    save();
  }

  void updateWeight(double newWeight) {
    weight = newWeight;
    save();
  }

  void updateReps(int newReps) {
    reps = newReps;
    save();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${seconds}s';
  }
}

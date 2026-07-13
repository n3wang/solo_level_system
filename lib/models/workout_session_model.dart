// lib/models/workout_session_model.dart
import 'package:hive/hive.dart';
part 'workout_session_model.g.dart';

@HiveType(typeId: 7)
class WorkoutSessionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String routineId;

  @HiveField(2)
  String routineName;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  DateTime? endTime;

  @HiveField(5)
  int durationMinutes; // Actual duration

  @HiveField(6)
  List<String> completedExerciseIds;

  @HiveField(7)
  Map<String, int> exerciseCompletedSets; // exerciseId -> completed sets count

  @HiveField(8)
  bool isCompleted;

  @HiveField(9)
  String status; // 'active', 'paused', 'completed', 'cancelled'

  @HiveField(10)
  String? notes;

  @HiveField(11)
  double? totalWeightLifted; // Sum of all weight * reps

  @HiveField(12)
  int totalSetsCompleted;

  @HiveField(13)
  int totalRepsCompleted;

  @HiveField(14)
  List<String> personalRecordsSet; // Exercise IDs where PR was achieved

  @HiveField(15)
  int caloriesBurned; // Estimated

  @HiveField(16)
  double? averageHeartRate;

  @HiveField(17)
  List<String> tags;

  @HiveField(18)
  String? location; // 'home', 'gym', 'outdoor'

  @HiveField(19)
  Map<String, dynamic> additionalData; // For future extensibility

  WorkoutSessionModel({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.completedExerciseIds = const [],
    this.exerciseCompletedSets = const {},
    this.isCompleted = false,
    this.status = 'active',
    this.notes,
    this.totalWeightLifted,
    this.totalSetsCompleted = 0,
    this.totalRepsCompleted = 0,
    this.personalRecordsSet = const [],
    this.caloriesBurned = 0,
    this.averageHeartRate,
    this.tags = const [],
    this.location,
    this.additionalData = const {},
  });

  // Convenience getters
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'In Progress';
      case 'paused':
        return 'Paused';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCancelled => status == 'cancelled';

  double get completionPercentage {
    if (exerciseCompletedSets.isEmpty) return 0.0;
    // This would need access to the routine to calculate properly
    // For now, return a simple calculation
    return totalSetsCompleted > 0 ? 1.0 : 0.0;
  }

  bool get hasPersonalRecords => personalRecordsSet.isNotEmpty;

  String get formattedWeightLifted {
    if (totalWeightLifted == null) return 'N/A';
    if (totalWeightLifted! >= 1000) {
      return '${(totalWeightLifted! / 1000).toStringAsFixed(1)}k kg';
    }
    return '${totalWeightLifted!.toStringAsFixed(0)} kg';
  }

  // Methods
  void startSession() {
    status = 'active';
    startTime = DateTime.now();
    save();
  }

  void pauseSession() {
    status = 'paused';
    _updateDuration();
    save();
  }

  void resumeSession() {
    status = 'active';
    save();
  }

  void completeSession() {
    status = 'completed';
    isCompleted = true;
    endTime = DateTime.now();
    _updateDuration();
    save();
  }

  void cancelSession() {
    status = 'cancelled';
    endTime = DateTime.now();
    _updateDuration();
    save();
  }

  void completeExercise(String exerciseId) {
    if (!completedExerciseIds.contains(exerciseId)) {
      completedExerciseIds.add(exerciseId);
      save();
    }
  }

  void completeSet(String exerciseId, int reps, double? weight) {
    exerciseCompletedSets[exerciseId] =
        (exerciseCompletedSets[exerciseId] ?? 0) + 1;
    totalSetsCompleted++;
    totalRepsCompleted += reps;

    if (weight != null) {
      totalWeightLifted = (totalWeightLifted ?? 0) + (weight * reps);
    }

    save();
  }

  void addPersonalRecord(String exerciseId) {
    if (!personalRecordsSet.contains(exerciseId)) {
      personalRecordsSet.add(exerciseId);
      if (isInBox) save();
    }
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      save();
    }
  }

  void updateNotes(String newNotes) {
    notes = newNotes;
    save();
  }

  void updateLocation(String newLocation) {
    location = newLocation;
    save();
  }

  void _updateDuration() {
    if (endTime != null) {
      durationMinutes = endTime!.difference(startTime).inMinutes;
    } else {
      durationMinutes = DateTime.now().difference(startTime).inMinutes;
    }
  }

  // Calculate current duration without saving
  int getCurrentDurationMinutes() {
    final now = endTime ?? DateTime.now();
    return now.difference(startTime).inMinutes;
  }
}

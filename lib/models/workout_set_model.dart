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
  int reps; // Number of sets/reps

  @HiveField(3)
  String measurementType; // 'kg', 'lbs', 'seconds', 'none'

  @HiveField(4)
  double? value; // The actual value: weight (kg/lbs), duration (seconds), or null for 'none'

  @HiveField(5)
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
  String? targetMeasurementType; // Target measurement type

  @HiveField(12)
  double? targetValue; // Target value

  WorkoutSetModel({
    required this.id,
    required this.exerciseId,
    required this.reps,
    this.measurementType = 'kg', // Default to kg for backward compatibility
    this.value,
    this.restTimeSeconds = 60,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
    this.targetReps,
    this.targetMeasurementType,
    this.targetValue,
  });

  // Convenience getters
  String get displayText {
    return displayTextWithUnit(measurementType);
  }

  /// Get display text with proper unit based on measurement type
  String displayTextWithUnit(String? unitOverride) {
    final unit = unitOverride ?? measurementType;
    
    switch (unit) {
      case 'seconds':
        // Time-based exercise (e.g., plank)
        if (value != null) {
          return _formatDuration(value!.toInt());
        }
        return '$reps sets';
      case 'none':
        // Bodyweight exercise with no weight/duration tracking
        return '$reps reps';
      case 'lbs':
        // Weight in pounds
        if (value != null) {
          return '$reps reps @ ${value}lbs';
        }
        return '$reps reps';
      case 'kg':
      default:
        // Weight in kilograms (default)
        if (value != null) {
          return '$reps reps @ ${value}kg';
        }
        return '$reps reps';
    }
  }

  /// Check if this set uses weight
  bool get usesWeight => (measurementType == 'kg' || measurementType == 'lbs') && value != null;

  /// Check if this set uses duration
  bool get usesDuration => measurementType == 'seconds' && value != null;

  /// Check if this set is bodyweight only
  bool get isBodyweightOnly => measurementType == 'none' || value == null;

  bool get isPersonalRecord => value != null; // Simplified for now

  /// Get weight value (if type is kg or lbs)
  double? get weight => (measurementType == 'kg' || measurementType == 'lbs') ? value : null;

  /// Get duration value in seconds (if type is seconds)
  int? get duration => measurementType == 'seconds' && value != null ? value!.toInt() : null;

  String get restTimeFormatted => _formatDuration(restTimeSeconds);

  // Methods
  void complete() {
    isCompleted = true;
    completedAt = DateTime.now();
    save();
  }

  void updateValue(double? newValue, String type) {
    value = newValue;
    measurementType = type;
    save();
  }

  void updateWeight(double newWeight) {
    value = newWeight;
    if (measurementType != 'kg' && measurementType != 'lbs') {
      measurementType = 'kg'; // Default to kg if not already set
    }
    save();
  }

  void updateDuration(int newDuration) {
    value = newDuration.toDouble();
    measurementType = 'seconds';
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
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${seconds}s';
  }
}

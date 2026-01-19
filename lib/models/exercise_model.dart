// lib/models/exercise_model.dart
import 'package:hive/hive.dart';
part 'exercise_model.g.dart';

@HiveType(typeId: 4)
class ExerciseModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String category; // 'strength', 'cardio', 'flexibility', 'sports'

  @HiveField(4)
  String muscleGroup; // 'chest', 'back', 'legs', 'arms', 'core', 'full_body'

  @HiveField(5)
  String equipment; // 'bodyweight', 'dumbbells', 'barbell', 'machine', 'cables'

  @HiveField(6)
  String difficulty; // 'beginner', 'intermediate', 'advanced'

  @HiveField(7)
  List<String> instructions;

  @HiveField(8)
  String? videoUrl;

  @HiveField(9)
  String? imageUrl;

  @HiveField(10)
  bool isCustom; // User-created vs built-in exercises

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime? modifiedAt;

  @HiveField(13)
  List<String> tags;

  @HiveField(14)
  bool isArchived;

  @HiveField(15)
  int timesPerformed; // Usage statistics

  @HiveField(16)
  double? personalRecord; // Best weight/time/distance

  @HiveField(17)
  String? personalRecordUnit; // 'kg', 'lbs', 'minutes', 'km'

  @HiveField(18)
  DateTime? personalRecordDate;

  @HiveField(19)
  List<int>? lastWorkoutReps; // Reps from last completed workout

  @HiveField(20)
  List<double?>? lastWorkoutWeights; // Weights from last completed workout

  @HiveField(21)
  DateTime? lastWorkoutDate; // Date of last completed workout

  ExerciseModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.muscleGroup,
    required this.equipment,
    required this.difficulty,
    required this.instructions,
    this.videoUrl,
    this.imageUrl,
    this.isCustom = true,
    required this.createdAt,
    this.modifiedAt,
    this.tags = const [],
    this.isArchived = false,
    this.timesPerformed = 0,
    this.personalRecord,
    this.personalRecordUnit,
    this.personalRecordDate,
    this.lastWorkoutReps,
    this.lastWorkoutWeights,
    this.lastWorkoutDate,
  });

  // Convenience getters
  String get displayName => name.trim();
  bool get hasPersonalRecord => personalRecord != null;
  String get formattedPersonalRecord => hasPersonalRecord
      ? '$personalRecord ${personalRecordUnit ?? ''}'
      : 'No PR';

  // Methods
  void incrementUsage() {
    timesPerformed++;
    save();
  }

  void updatePersonalRecord(double value, String unit) {
    if (personalRecord == null || value > personalRecord!) {
      personalRecord = value;
      personalRecordUnit = unit;
      personalRecordDate = DateTime.now();
      modifiedAt = DateTime.now();
      save();
    }
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
    isArchived = true;
    save();
  }

  void unarchive() {
    isArchived = false;
    save();
  }

  /// Update last workout data
  void updateLastWorkoutData(List<int> reps, List<double?> weights) {
    lastWorkoutReps = List<int>.from(reps);
    lastWorkoutWeights = List<double?>.from(weights);
    lastWorkoutDate = DateTime.now();
    modifiedAt = DateTime.now();
    save();
  }
}

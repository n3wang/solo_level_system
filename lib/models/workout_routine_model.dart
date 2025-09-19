// lib/models/workout_routine_model.dart
import 'package:hive/hive.dart';
import 'workout_set_model.dart';
part 'workout_routine_model.g.dart';

@HiveType(typeId: 6)
class WorkoutRoutineModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<String> exerciseIds; // Ordered list of exercises

  @HiveField(4)
  Map<String, List<WorkoutSetModel>> exerciseSets; // exerciseId -> sets

  @HiveField(5)
  String category; // 'strength', 'cardio', 'mixed', 'custom'

  @HiveField(6)
  String difficulty; // 'beginner', 'intermediate', 'advanced'

  @HiveField(7)
  int estimatedDurationMinutes;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  bool isTemplate; // Template vs active routine

  @HiveField(10)
  bool isFavorite;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime? modifiedAt;

  @HiveField(13)
  int timesCompleted;

  @HiveField(14)
  DateTime? lastCompletedAt;

  @HiveField(15)
  bool isArchived;

  @HiveField(16)
  String? notes;

  @HiveField(17)
  List<String> targetMuscleGroups;

  @HiveField(18)
  String? createdBy; // 'user' or 'system' or trainer name

  WorkoutRoutineModel({
    required this.id,
    required this.name,
    required this.description,
    this.exerciseIds = const [],
    this.exerciseSets = const {},
    required this.category,
    required this.difficulty,
    this.estimatedDurationMinutes = 30,
    this.tags = const [],
    this.isTemplate = true,
    this.isFavorite = false,
    required this.createdAt,
    this.modifiedAt,
    this.timesCompleted = 0,
    this.lastCompletedAt,
    this.isArchived = false,
    this.notes,
    this.targetMuscleGroups = const [],
    this.createdBy = 'user',
  });

  // Convenience getters
  int get totalExercises => exerciseIds.length;

  int get totalSets {
    return exerciseSets.values.fold(0, (sum, sets) => sum + sets.length);
  }

  String get formattedDuration {
    final hours = estimatedDurationMinutes ~/ 60;
    final minutes = estimatedDurationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get lastCompletedFormatted {
    if (lastCompletedAt == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastCompletedAt!);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} weeks ago';
    return '${difference.inDays ~/ 30} months ago';
  }

  bool get hasBeenCompleted => timesCompleted > 0;

  // Methods
  void addExercise(String exerciseId, List<WorkoutSetModel> sets) {
    exerciseIds.add(exerciseId);
    exerciseSets[exerciseId] = sets;
    modifiedAt = DateTime.now();
    save();
  }

  void removeExercise(String exerciseId) {
    exerciseIds.remove(exerciseId);
    exerciseSets.remove(exerciseId);
    modifiedAt = DateTime.now();
    save();
  }

  void updateSets(String exerciseId, List<WorkoutSetModel> sets) {
    exerciseSets[exerciseId] = sets;
    modifiedAt = DateTime.now();
    save();
  }

  void reorderExercises(List<String> newOrder) {
    exerciseIds = newOrder;
    modifiedAt = DateTime.now();
    save();
  }

  void markCompleted() {
    timesCompleted++;
    lastCompletedAt = DateTime.now();
    save();
  }

  void toggleFavorite() {
    isFavorite = !isFavorite;
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
    isArchived = true;
    save();
  }

  void unarchive() {
    isArchived = false;
    save();
  }

  // Create a copy for starting a new session
  WorkoutRoutineModel createSessionCopy() {
    return WorkoutRoutineModel(
      id: '${id}_session_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      exerciseIds: List.from(exerciseIds),
      exerciseSets: Map.from(exerciseSets),
      category: category,
      difficulty: difficulty,
      estimatedDurationMinutes: estimatedDurationMinutes,
      tags: List.from(tags),
      isTemplate: false,
      createdAt: DateTime.now(),
      targetMuscleGroups: List.from(targetMuscleGroups),
      createdBy: createdBy,
    );
  }
}

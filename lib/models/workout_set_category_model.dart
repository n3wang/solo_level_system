// lib/models/workout_set_category_model.dart
import 'package:hive/hive.dart';
part 'workout_set_category_model.g.dart';

@HiveType(typeId: 15) // Using a new typeId
class WorkoutSetCategoryModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Set 1", "Set 2", etc.

  @HiveField(2)
  int position; // 0-4 for 5 sets max

  @HiveField(3)
  String description;

  @HiveField(4)
  List<String> exerciseIds; // Exercises belonging to this set

  @HiveField(5)
  String? color; // Optional color for the set

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? modifiedAt;

  @HiveField(9)
  DateTime? lastPerformanceDate; // Last time this set was performed

  WorkoutSetCategoryModel({
    required this.id,
    required this.name,
    required this.position,
    this.description = '',
    required this.exerciseIds,
    this.color,
    this.isActive = true,
    required this.createdAt,
    this.modifiedAt,
    this.lastPerformanceDate,
  });

  // Convenience methods
  void addExercise(String exerciseId) {
    if (!exerciseIds.contains(exerciseId)) {
      exerciseIds.add(exerciseId);
      modifiedAt = DateTime.now();
      save();
    }
  }

  void removeExercise(String exerciseId) {
    exerciseIds.remove(exerciseId);
    modifiedAt = DateTime.now();
    save();
  }

  void updateName(String newName) {
    name = newName;
    modifiedAt = DateTime.now();
    save();
  }

  void updateDescription(String newDescription) {
    description = newDescription;
    modifiedAt = DateTime.now();
    save();
  }

  void updatePosition(int newPosition) {
    if (newPosition >= 0 && newPosition < 5) {
      position = newPosition;
      modifiedAt = DateTime.now();
      save();
    }
  }

  WorkoutSetCategoryModel copyWith({
    String? id,
    String? name,
    int? position,
    String? description,
    List<String>? exerciseIds,
    String? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? lastPerformanceDate,
  }) {
    return WorkoutSetCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      description: description ?? this.description,
      exerciseIds: exerciseIds ?? List.from(this.exerciseIds),
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastPerformanceDate: lastPerformanceDate ?? this.lastPerformanceDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'description': description,
      'exerciseIds': exerciseIds,
      'color': color,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'lastPerformanceDate': lastPerformanceDate?.toIso8601String(),
    };
  }

  factory WorkoutSetCategoryModel.fromJson(Map<String, dynamic> json) {
    return WorkoutSetCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as int,
      description: json['description'] as String? ?? '',
      exerciseIds: List<String>.from(json['exerciseIds'] as List),
      color: json['color'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      lastPerformanceDate: json['lastPerformanceDate'] != null
          ? DateTime.parse(json['lastPerformanceDate'] as String)
          : null,
    );
  }

  void updateLastPerformanceDate(DateTime date) {
    lastPerformanceDate = date;
    modifiedAt = DateTime.now();
    save();
  }
}

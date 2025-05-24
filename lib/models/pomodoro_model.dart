// lib/models/pomodoro_model.dart
import 'package:hive/hive.dart';
part 'pomodoro_model.g.dart';

@HiveType(typeId: 0)
class PomodoroModel extends HiveObject {
  @HiveField(0)
  DateTime startTime;

  @HiveField(1)
  String? audioPath;

  @HiveField(2)
  String? imagePath;

  @HiveField(3)
  int? dayPomodoroNumber;

  @HiveField(4)
  String? duration;

  @HiveField(5)
  String? project_id;

  // project name.
  @HiveField(6)
  String? project_name;

  PomodoroModel({
    required this.startTime,
    this.audioPath,
    this.imagePath,
    this.dayPomodoroNumber,
    this.duration,
    this.project_id,
    this.project_name,
  });
}

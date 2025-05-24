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

  // @HiveField(3)
  // String? notes;

  // @HiveField(4)
  // String? duration;

  PomodoroModel({required this.startTime, this.audioPath, this.imagePath});
}

import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';

Future<int> getTodayCompletedSessions() async {
  final box = Hive.box<PomodoroModel>('pomodoros');
  final today = DateTime.now();
  final completedSessions = box.values.where((session) {
    return session.startTime.year == today.year &&
        session.startTime.month == today.month &&
        session.startTime.day == today.day;
  }).toList();

  print("Today's completed sessions: $completedSessions");
  return completedSessions.length;
}

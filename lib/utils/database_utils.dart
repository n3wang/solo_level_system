import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/utils/dev_data.dart';

Future<int> getTodayCompletedSessions() async {
  final box = Hive.box<PomodoroModel>('pomodoros');
  final today = DateTime.now();
  final completedSessions = box.values.where((session) {
    if (!DevData.keepVisible(projectId: session.project_id)) return false;
    final start = session.startTime.toLocal();
    return start.year == today.year &&
        start.month == today.month &&
        start.day == today.day;
  }).toList();

  print("Today's completed sessions: $completedSessions");
  return completedSessions.length;
}

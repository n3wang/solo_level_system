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

  /// Legacy string storage (e.g. `"25"`). Prefer [durationMinutes].
  @HiveField(4)
  String? duration;

  @HiveField(5)
  String? project_id;

  // project name.
  @HiveField(6)
  String? project_name;

  /// Focus session length in minutes. Source of truth for analytics.
  @HiveField(7)
  int? durationMinutes;

  PomodoroModel({
    required this.startTime,
    this.audioPath,
    this.imagePath,
    this.dayPomodoroNumber,
    this.duration,
    this.project_id,
    this.project_name,
    this.durationMinutes,
  });

  /// Resolved focus minutes: [durationMinutes], then legacy [duration], else 25.
  int get minutesSpent {
    final stored = durationMinutes;
    if (stored != null && stored > 0) return stored;
    return _parseLegacyDuration(duration);
  }

  static int _parseLegacyDuration(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return 25;
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0) return asInt;
    final parts = trimmed.split(':');
    if (parts.isNotEmpty) {
      final hoursOrMinutes = int.tryParse(parts.first);
      if (hoursOrMinutes == null) return 25;
      if (parts.length >= 2) {
        // Treat as H:MM (or M:SS) — take minutes from first two parts when H:MM.
        final second = int.tryParse(parts[1]) ?? 0;
        if (parts.length >= 3 || hoursOrMinutes > 59) {
          return (hoursOrMinutes * 60) + second;
        }
        return hoursOrMinutes;
      }
      return hoursOrMinutes;
    }
    return 25;
  }
}

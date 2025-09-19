// lib/utils/hive_utils.dart
import 'package:hive/hive.dart';

class HiveUtils {
  /// Ensures a Hive box is open, opening it if necessary
  static Future<void> ensureBoxIsOpen<T>(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        print('Opening Hive box: $boxName');
        await Hive.openBox<T>(boxName);
        print('✓ Opened $boxName box');
      }
    } catch (e) {
      print('Error opening box $boxName: $e');
      rethrow;
    }
  }

  /// Safely gets a Hive box, ensuring it's open first
  static Future<Box<T>> safeGetBox<T>(String boxName) async {
    await ensureBoxIsOpen<T>(boxName);
    return Hive.box<T>(boxName);
  }

  /// Checks if a box is open and ready to use
  static bool isBoxReady(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  /// Gets box names for all workout-related boxes
  static List<String> get workoutBoxNames => [
    'exercises',
    'workoutRoutines',
    'workoutSessions',
    'habits',
  ];

  /// Gets box names for all core app boxes
  static List<String> get coreBoxNames => [
    'pomodoros',
    'userSettings',
    'audioSettings',
    'audioFiles',
    'config',
  ];

  /// Gets all box names
  static List<String> get allBoxNames => [...coreBoxNames, ...workoutBoxNames];
}

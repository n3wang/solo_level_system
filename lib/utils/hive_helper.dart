// lib/utils/hive_helper.dart
import 'package:hive_flutter/hive_flutter.dart';

/// Utility class for Hive box operations with error recovery
class HiveHelper {
  HiveHelper._();

  /// Opens a Hive box with automatic error recovery.
  /// If the box fails to open (e.g., due to corrupted data or type changes),
  /// it will delete and recreate the box.
  static Future<Box<T>> openBoxWithRecovery<T>(
    String boxName, {
    bool verbose = false,
  }) async {
    try {
      final box = await Hive.openBox<T>(boxName);
      if (verbose) {
        print('\u2713 Opened $boxName box');
      }
      return box;
    } catch (e) {
      if (verbose) {
        print('\u26a0\ufe0f Error opening $boxName box, clearing and recreating: $e');
      }
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (deleteError) {
        if (verbose) {
          print('Note: Could not delete $boxName box (may not exist): $deleteError');
        }
      }
      final box = await Hive.openBox<T>(boxName);
      if (verbose) {
        print('\u2713 Recreated $boxName box');
      }
      return box;
    }
  }

  /// Ensures a Hive box is open, opening it if necessary.
  /// Does not perform error recovery - use openBoxWithRecovery for that.
  static Future<Box<T>> ensureBoxOpen<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return Hive.openBox<T>(boxName);
  }

  /// Gets a value from a box with a default fallback.
  /// Opens the box if not already open.
  static Future<T> getOrDefault<T>(
    String boxName,
    String key,
    T defaultValue,
  ) async {
    final box = await ensureBoxOpen<T>(boxName);
    return box.get(key) ?? defaultValue;
  }

  /// Puts a value in a box.
  /// Opens the box if not already open.
  static Future<void> put<T>(String boxName, String key, T value) async {
    final box = await ensureBoxOpen<T>(boxName);
    await box.put(key, value);
  }

  /// Gets all values from a box as a list.
  /// Opens the box if not already open.
  static Future<List<T>> getAll<T>(String boxName) async {
    final box = await ensureBoxOpen<T>(boxName);
    return box.values.toList();
  }

  /// Clears all data from a box.
  /// Opens the box if not already open.
  static Future<void> clear<T>(String boxName) async {
    final box = await ensureBoxOpen<T>(boxName);
    await box.clear();
  }
}

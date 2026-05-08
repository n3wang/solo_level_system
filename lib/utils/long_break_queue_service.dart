import 'package:hive/hive.dart';
import 'package:solo_level_system/models/long_break_queue_item_model.dart';
import 'package:uuid/uuid.dart';

class LongBreakQueueService {
  LongBreakQueueService._();

  static const String _boxName = 'longBreakQueue';
  static const String _appFlagsBoxName = 'app_init_flags';
  static const String _sheetReminderNoteKey = 'long_break_sheet_reminder_note';
  static const _uuid = Uuid();

  static Future<Box<dynamic>> _openFlagsBox() async {
    if (Hive.isBoxOpen(_appFlagsBoxName)) {
      return Hive.box(_appFlagsBoxName);
    }
    return Hive.openBox(_appFlagsBoxName);
  }

  /// Free-form reminder shown at the top of the long-break sheet (e.g. before eating).
  static Future<String> getSheetReminderNote() async {
    try {
      final box = await _openFlagsBox();
      return box.get(_sheetReminderNoteKey, defaultValue: '') as String;
    } catch (_) {
      return '';
    }
  }

  static Future<void> saveSheetReminderNote(String note) async {
    try {
      final box = await _openFlagsBox();
      await box.put(_sheetReminderNoteKey, note);
    } catch (_) {
      // Non-fatal
    }
  }

  static Future<Box<LongBreakQueueItemModel>> openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<LongBreakQueueItemModel>(_boxName);
    }
    return Hive.openBox<LongBreakQueueItemModel>(_boxName);
  }

  static Future<List<LongBreakQueueItemModel>> activeItems() async {
    final box = await openBox();
    final list =
        box.values.where((e) => !e.isArchived).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<List<LongBreakQueueItemModel>> archivedItems() async {
    final box = await openBox();
    final list =
        box.values.where((e) => e.isArchived).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> save(LongBreakQueueItemModel item) async {
    final box = await openBox();
    await box.put(item.id, item);
  }

  static Future<void> delete(String id) async {
    final box = await openBox();
    await box.delete(id);
  }

  static String newId() => _uuid.v4();

}

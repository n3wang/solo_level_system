import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class InstallIdService {
  static const boxName = 'app_init_flags';
  static const key = 'installId';

  static Future<String> getOrCreate() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    final box = Hive.box(boxName);
    final existing = box.get(key);
    if (existing is String && existing.isNotEmpty) {
      return existing;
    }
    final id = const Uuid().v4();
    await box.put(key, id);
    return id;
  }
}

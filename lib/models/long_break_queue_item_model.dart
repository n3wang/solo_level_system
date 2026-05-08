import 'package:hive/hive.dart';

part 'long_break_queue_item_model.g.dart';

@HiveType(typeId: 28)
class LongBreakQueueItemModel extends HiveObject {
  @HiveField(0)
  String id;

  /// Playlist URL, video URL, or pasted link.
  @HiveField(1)
  String url;

  /// Shown when non-empty; otherwise a short form of [url] is used.
  @HiveField(2)
  String? customName;

  @HiveField(3)
  bool hasChapters;

  /// 1-based chapter index when [hasChapters] is true.
  @HiveField(4)
  int currentChapter;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  bool isArchived;

  @HiveField(7)
  DateTime createdAt;

  LongBreakQueueItemModel({
    required this.id,
    required this.url,
    this.customName,
    this.hasChapters = false,
    this.currentChapter = 1,
    this.isCompleted = false,
    this.isArchived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String shortUrl() {
    final t = url.trim();
    if (t.length <= 42) return t;
    return '${t.substring(0, 39)}…';
  }

  String displayLabel() {
    final base =
        (customName != null && customName!.trim().isNotEmpty)
            ? customName!.trim()
            : shortUrl();
    if (!hasChapters) return base;
    return '$base · c$currentChapter';
  }
}

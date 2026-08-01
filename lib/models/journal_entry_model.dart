import 'package:hive/hive.dart';

part 'journal_entry_model.g.dart';

/// A single item in the shared focus/workout journal feed.
@HiveType(typeId: 29)
class JournalEntryModel extends HiveObject {
  @HiveField(0)
  String id;

  /// text | audio | image | session | quote
  @HiveField(1)
  String type;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  String? text;

  @HiveField(4)
  String? mediaPath;

  @HiveField(5)
  int? durationMs;

  @HiveField(6)
  String? projectName;

  @HiveField(7)
  int? sessionMinutes;

  /// focus | workout | free
  @HiveField(8)
  String source;

  @HiveField(9)
  Map<String, dynamic> metadata;

  JournalEntryModel({
    required this.id,
    required this.type,
    required this.createdAt,
    this.text,
    this.mediaPath,
    this.durationMs,
    this.projectName,
    this.sessionMinutes,
    this.source = 'free',
    this.metadata = const {},
  });

  bool get isText => type == 'text';
  bool get isAudio => type == 'audio';
  bool get isImage => type == 'image';
  bool get isSession => type == 'session';
  bool get isQuote => type == 'quote';
}

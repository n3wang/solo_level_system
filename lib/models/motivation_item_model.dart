import 'package:hive/hive.dart';

part 'motivation_item_model.g.dart';

@HiveType(typeId: 26)
class MotivationItemModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type; // quote | reward | collection

  @HiveField(2)
  String title;

  @HiveField(3)
  String description;

  @HiveField(4)
  String category;

  @HiveField(5)
  int pointsCost;

  @HiveField(6)
  bool isAcquired;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? acquiredAt;

  @HiveField(9)
  bool isSystem;

  @HiveField(10)
  String? quotePerson;

  @HiveField(11)
  String? quoteText;

  @HiveField(12)
  int? imageIndex;

  @HiveField(13)
  Map<String, dynamic> metadata;

  MotivationItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.pointsCost,
    this.isAcquired = false,
    required this.createdAt,
    this.acquiredAt,
    this.isSystem = true,
    this.quotePerson,
    this.quoteText,
    this.imageIndex,
    this.metadata = const {},
  });
}


// lib/models/motivational_card_model.dart
import 'package:hive/hive.dart';

part 'motivational_card_model.g.dart';

@HiveType(typeId: 23)
class MotivationalCardModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  String? imagePath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? updatedAt;

  MotivationalCardModel({
    required this.id,
    required this.text,
    this.imagePath,
    required this.createdAt,
    this.updatedAt,
  });
}

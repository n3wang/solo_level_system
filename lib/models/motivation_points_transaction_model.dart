import 'package:hive/hive.dart';

part 'motivation_points_transaction_model.g.dart';

@HiveType(typeId: 27)
class MotivationPointsTransactionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String kind; // earned | spent

  @HiveField(2)
  int amount;

  @HiveField(3)
  String source; // pomodoro | reward_purchase | collection_unlock | etc

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  Map<String, dynamic> metadata;

  MotivationPointsTransactionModel({
    required this.id,
    required this.kind,
    required this.amount,
    required this.source,
    required this.createdAt,
    this.metadata = const {},
  });
}


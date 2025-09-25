// lib/models/reward_model.dart
import 'package:hive/hive.dart';
part 'reward_model.g.dart';

@HiveType(typeId: 22)
class RewardModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  int pointsCost;

  @HiveField(4)
  String category;

  @HiveField(5)
  String? iconName;

  @HiveField(6)
  String? color; // Hex color code

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  bool isCustom; // User-created vs system reward

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime? purchasedAt;

  @HiveField(11)
  int timesPurchased;

  @HiveField(12)
  bool isRecurring; // Can be purchased multiple times

  @HiveField(13)
  int? maxPurchases; // Null means unlimited

  @HiveField(14)
  Map<String, dynamic> metadata; // Additional data

  @HiveField(15)
  List<String> tags;

  @HiveField(16)
  int priority; // For sorting

  RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    this.category = 'general',
    this.iconName,
    this.color,
    this.isActive = true,
    this.isCustom = true, // All rewards are user-created
    required this.createdAt,
    this.purchasedAt,
    this.timesPurchased = 0,
    this.isRecurring = true,
    this.maxPurchases,
    this.metadata = const {},
    this.tags = const [],
    this.priority = 0,
  });

  // Convenience getters
  bool get canBePurchased {
    if (!isActive) return false;
    if (maxPurchases == null) return true;
    return timesPurchased < maxPurchases!;
  }

  bool get wasEverPurchased => timesPurchased > 0;

  String get categoryDisplay {
    switch (category) {
      case 'electronics':
        return 'Electronics';
      case 'entertainment':
        return 'Entertainment';
      case 'food':
        return 'Food & Treats';
      case 'shopping':
        return 'Shopping';
      case 'activities':
        return 'Activities';
      case 'tools':
        return 'Tools & Equipment';
      case 'books':
        return 'Books & Learning';
      case 'health':
        return 'Health & Fitness';
      case 'travel':
        return 'Travel & Experiences';
      case 'general':
      default:
        return 'General';
    }
  }

  String get remainingPurchases {
    if (maxPurchases == null) return 'Unlimited';
    return '${maxPurchases! - timesPurchased} remaining';
  }

  // Methods
  void purchase() {
    timesPurchased++;
    purchasedAt = DateTime.now();

    if (maxPurchases != null && timesPurchased >= maxPurchases!) {
      isActive = false; // Disable if max reached
    }

    save();
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      save();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    save();
  }

  void updateMetadata(String key, dynamic value) {
    metadata[key] = value;
    save();
  }

  void activate() {
    isActive = true;
    save();
  }

  void deactivate() {
    isActive = false;
    save();
  }

  @override
  String toString() {
    return 'Reward(title: $title, cost: $pointsCost, purchased: $timesPurchased times)';
  }
}

// Helper class for reward creation and management
class RewardTemplates {
  static RewardModel createCustomReward({
    required String title,
    required String description,
    required int pointsCost,
    String category = 'general',
    String? iconName,
    String? color,
    bool isRecurring = true,
    int? maxPurchases,
    List<String> tags = const [],
  }) {
    return RewardModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      pointsCost: pointsCost,
      category: category,
      iconName: iconName,
      color: color,
      isCustom: true, // Always true - all rewards are user-created
      createdAt: DateTime.now(),
      isRecurring: isRecurring,
      maxPurchases: maxPurchases,
      tags: tags,
    );
  }
}

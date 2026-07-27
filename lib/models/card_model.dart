import 'package:hive/hive.dart';

part 'card_model.g.dart';

/// The kind of thing a [CardModel] represents. Persisted as a lowercase wire
/// string in [CardModel.type] for backward compatibility with existing Hive
/// data (values `quote | collection | reward` predate the broader catalog).
enum CardType {
  /// Philosopher, author, creator, or source of knowledge/creations.
  phy('phy'),
  collection('collection'),
  reward('reward'),
  room('room'),
  music('music'),
  exercise('exercise'),
  option('option');

  const CardType(this.wire);

  /// The string stored in Hive / used in filters.
  final String wire;

  /// Tolerant parse: unknown or null values fall back to [CardType.collection]
  /// so legacy or malformed records still render instead of throwing.
  static CardType parse(String? raw) {
    final value = raw?.trim().toLowerCase();
    for (final type in CardType.values) {
      if (type.wire == value) return type;
    }
    return CardType.collection;
  }
}

/// Drop / display tier. Drives session-loot draw weight and hub tinting.
enum CardRarity {
  common('common'),
  uncommon('uncommon'),
  rare('rare'),
  epic('epic');

  const CardRarity(this.wire);

  final String wire;

  static CardRarity parse(String? raw) {
    final value = raw?.trim().toLowerCase();
    for (final rarity in CardRarity.values) {
      if (rarity.wire == value) return rarity;
    }
    return CardRarity.common;
  }
}

/// A collectible catalog entry. Acquiring a card unlocks the thing it
/// represents in the rest of the app (an exercise or program, room, track,
/// or a system option - either a stackable capacity setting or screen guide).
///
/// Formerly `MotivationItemModel`. Hive `typeId` (26) and field indices are
/// preserved so existing data reads without migration; the box remains
/// `motivationItems`.
@HiveType(typeId: 26)
class CardModel extends HiveObject {
  @HiveField(0)
  String id;

  /// Persisted [CardType] wire string. Prefer [cardType] for typed access.
  @HiveField(1)
  String type;

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

  @HiveField(14)
  int acquisitionCount;

  @HiveField(15)
  List<DateTime> acquisitionHistory;

  /// Id of the asset/setting this card unlocks: an exercise (or program with
  /// bundled exercises), music track, room, or option key (setting or screen).
  /// Null for purely collectible cards (`quote` / `collection`).
  @HiveField(16)
  String? unlockTargetId;

  /// Persisted [CardRarity] wire string. Prefer [rarityTier] for typed access.
  @HiveField(17)
  String rarity;

  /// Seeded first-run card that ships already acquired.
  @HiveField(18)
  bool isStarter;

  CardModel({
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
    this.acquisitionCount = 0,
    this.acquisitionHistory = const [],
    this.unlockTargetId,
    this.rarity = 'common',
    this.isStarter = false,
  });

  /// Typed view of [type].
  CardType get cardType => CardType.parse(type);
  set cardType(CardType value) => type = value.wire;

  /// Typed view of [rarity].
  CardRarity get rarityTier => CardRarity.parse(rarity);
  set rarityTier(CardRarity value) => rarity = value.wire;

  bool get hasAnyAcquisition => acquisitionCount > 0 || isAcquired;

  void recordAcquisition() {
    final now = DateTime.now();
    acquisitionCount += 1;
    isAcquired = true;
    acquiredAt = now;
    acquisitionHistory = [...acquisitionHistory, now];
  }
}

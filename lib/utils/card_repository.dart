import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/reward_model.dart';

/// Unified, presentation-facing view of a catalog entry, regardless of whether
/// it is backed by a [CardModel] or a (legacy) [RewardModel]. Screens consume
/// [CatalogCard]; only the repository knows about the two source boxes.
class CatalogCard {
  final String id;
  final CardType type;
  final String title;
  final String description;
  final String category;
  final int pointsCost;
  final bool isAcquired;
  final int acquisitionCount;
  final int? imageIndex;

  /// Optional asset image path (e.g. an exercise icon / album art / room icon).
  final String? imageAsset;

  /// Optional device file path (user gallery image on custom rewards).
  final String? localImagePath;

  /// Room preview visuals (asset paths). Empty for non-room cards.
  final List<String> visuals;

  /// How many music tracks this room card bundles (for detail copy).
  final int bundledMusicCount;

  final CardRarity rarity;
  final String? unlockTargetId;
  final CardModel? sourceItem;
  final RewardModel? sourceReward;

  const CatalogCard({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.pointsCost,
    required this.isAcquired,
    this.acquisitionCount = 0,
    this.imageIndex,
    this.imageAsset,
    this.localImagePath,
    this.visuals = const [],
    this.bundledMusicCount = 0,
    this.rarity = CardRarity.common,
    this.unlockTargetId,
    this.sourceItem,
    this.sourceReward,
  });

  /// Wire string of [type] (matches the hub filter values).
  String get typeWire => type.wire;
}

/// Builds the merged hub catalog from both source boxes and hides
/// collectible-reward duplicates (those surface as `collection` cards).
class CardRepository {
  CardRepository._();

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static CatalogCard fromCardModel(CardModel item) {
    final meta = item.metadata;
    final imageAsset = meta['imageAsset'] is String
        ? meta['imageAsset'] as String
        : null;
    final localImage = meta['localImagePath'] is String
        ? meta['localImagePath'] as String
        : null;
    final visuals = _stringList(meta['visuals']);
    final bundled = meta['bundledMusicCount'];
    return CatalogCard(
      id: item.id,
      type: item.cardType,
      title: item.title,
      description: item.description,
      category: item.category,
      pointsCost: item.pointsCost,
      isAcquired: item.hasAnyAcquisition,
      acquisitionCount: item.acquisitionCount,
      imageIndex: item.imageIndex,
      imageAsset: imageAsset,
      localImagePath: localImage,
      visuals: visuals,
      bundledMusicCount: bundled is num ? bundled.toInt() : 0,
      rarity: item.rarityTier,
      unlockTargetId: item.unlockTargetId,
      sourceItem: item,
    );
  }

  static List<CatalogCard> build({
    required List<CardModel> cards,
    required List<RewardModel> rewards,
  }) {
    final result = <CatalogCard>[];

    for (final item in cards) {
      result.add(fromCardModel(item));
    }

    for (final reward in rewards) {
      final isCollectibleSeed =
          reward.metadata['isCollectible'] == true ||
          reward.metadata['source'] == 'default_boardgame_csv' ||
          reward.tags.contains('collectible');
      if (isCollectibleSeed) continue;

      final boardgameNumber = reward.metadata['boardgameNumber'];
      final imageAsset = reward.metadata['imageAsset'] is String
          ? reward.metadata['imageAsset'] as String
          : null;
      final localImage = reward.metadata['localImagePath'] is String
          ? reward.metadata['localImagePath'] as String
          : null;
      result.add(
        CatalogCard(
          id: reward.id,
          type: CardType.reward,
          title: reward.title,
          description: reward.description,
          category: reward.category,
          pointsCost: reward.pointsCost,
          isAcquired: reward.timesPurchased > 0,
          acquisitionCount: reward.timesPurchased,
          imageIndex: boardgameNumber is num ? boardgameNumber.toInt() : null,
          imageAsset: imageAsset,
          localImagePath: localImage,
          sourceReward: reward,
        ),
      );
    }

    return result;
  }
}

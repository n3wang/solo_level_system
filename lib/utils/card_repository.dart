import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/utils/dev_data.dart';

/// A single entry (quote, creation, work) in a phy card with optional link to another card.
///
/// Backward compatible: parses both legacy string entries and structured map format.
class PhyEntry {
  final String text;
  final String? linkedCardId;

  const PhyEntry({required this.text, this.linkedCardId});

  /// Parses a single entry from metadata. Handles:
  /// - String: legacy format (just the text)
  /// - Map: structured format with 'text' and optional 'linkedCardId'
  factory PhyEntry.fromRaw(dynamic raw) {
    if (raw is String) {
      return PhyEntry(text: raw.trim());
    }
    if (raw is Map) {
      return PhyEntry(
        text: (raw['text'] ?? '').toString().trim(),
        linkedCardId: raw['linkedCardId']?.toString(),
      );
    }
    return PhyEntry(text: raw.toString().trim());
  }

  /// Converts to a map for storage. Only includes linkedCardId if non-null.
  Map<String, dynamic> toJson() => {
        'text': text,
        if (linkedCardId != null) 'linkedCardId': linkedCardId,
      };

  /// Returns simple string if no link, otherwise full map.
  dynamic toStorage() => linkedCardId == null ? text : toJson();
}

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
  final bool isBookmarked;
  final CardModel? sourceItem;
  final RewardModel? sourceReward;

  /// True for timed workout programs (7 Minute Workout, etc.)
  final bool isProgram;

  /// Duration in seconds for program cards.
  final int durationSeconds;

  /// Exercise preview images for program cards (up to 3).
  final List<String> exerciseImages;

  /// Chrono Atlas / catalog geo facts (from CSV metadata).
  final int? year;
  final String? yearKind;
  final String? placeLabel;

  /// Display lifespan / era label from CSV `year_label` (e.g. `4 BC–65 AD`).
  final String? yearLabel;

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
    this.isBookmarked = false,
    this.sourceItem,
    this.sourceReward,
    this.isProgram = false,
    this.durationSeconds = 0,
    this.exerciseImages = const [],
    this.year,
    this.yearKind,
    this.placeLabel,
    this.yearLabel,
  });

  /// Wire string of [type] (matches the hub filter values).
  String get typeWire => type.wire;

  bool get hasPlaceLabel =>
      placeLabel != null && placeLabel!.trim().isNotEmpty;

  bool get hasYearLabel =>
      yearLabel != null && yearLabel!.trim().isNotEmpty;

  /// True when there is at least one catalog fact worth showing in detail.
  bool get hasCatalogFacts =>
      category.trim().isNotEmpty ||
      year != null ||
      hasYearLabel ||
      hasPlaceLabel;

  /// Preferred year display: CSV `year_label`, else numeric year (+ kind).
  String? get displayYearLabel {
    if (hasYearLabel) return yearLabel!.trim();
    final y = formattedYear;
    if (y == null) return null;
    final kind = yearKind?.trim();
    if (kind != null && kind.isNotEmpty) return '$y ($kind)';
    return y;
  }

  /// Formatted year for display (supports BCE via negative values).
  String? get formattedYear {
    final y = year;
    if (y == null) return null;
    if (y < 0) return '${y.abs()} BCE';
    return '$y';
  }

  /// Formatted duration for program cards (e.g., "7 min").
  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes min $seconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }
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

  static bool _isBookmarkedMeta(Map<String, dynamic> metadata) =>
      metadata['isBookmarked'] == true;

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
    final isProgram = meta['isProgram'] == true;
    final durationSeconds = meta['durationSeconds'] is num
        ? (meta['durationSeconds'] as num).toInt()
        : 0;
    final exerciseImages = _stringList(meta['exerciseImages']);
    final year = meta['year'] is int
        ? meta['year'] as int
        : int.tryParse('${meta['year'] ?? ''}');
    final yearKind = meta['yearKind'] is String
        ? (meta['yearKind'] as String).trim()
        : null;
    final placeLabel = meta['placeLabel'] is String
        ? (meta['placeLabel'] as String).trim()
        : null;
    final yearLabel = meta['yearLabel'] is String
        ? (meta['yearLabel'] as String).trim()
        : null;
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
      isBookmarked: _isBookmarkedMeta(meta),
      sourceItem: item,
      isProgram: isProgram,
      durationSeconds: durationSeconds,
      exerciseImages: exerciseImages,
      year: year,
      yearKind: yearKind != null && yearKind.isNotEmpty ? yearKind : null,
      placeLabel:
          placeLabel != null && placeLabel.isNotEmpty ? placeLabel : null,
      yearLabel: yearLabel != null && yearLabel.isNotEmpty ? yearLabel : null,
    );
  }

  /// Toggles bookmark on the backing Hive object. Returns the new value.
  static Future<bool> toggleBookmark(CatalogCard card) async {
    if (card.sourceItem != null) {
      final item = card.sourceItem!;
      final next = !_isBookmarkedMeta(item.metadata);
      item.metadata = {...item.metadata, 'isBookmarked': next};
      await item.save();
      return next;
    }
    if (card.sourceReward != null) {
      final reward = card.sourceReward!;
      final next = !_isBookmarkedMeta(reward.metadata);
      reward.metadata = {...reward.metadata, 'isBookmarked': next};
      await reward.save();
      return next;
    }
    return false;
  }

  /// Bookmarked cards sort before others (stable with a secondary comparator).
  static int compareBookmarkedFirst(CatalogCard a, CatalogCard b) {
    if (a.isBookmarked == b.isBookmarked) return 0;
    return a.isBookmarked ? -1 : 1;
  }

  static List<CatalogCard> build({
    required List<CardModel> cards,
    required List<RewardModel> rewards,
  }) {
    final result = <CatalogCard>[];

    for (final item in cards) {
      if (!DevData.showDevData && DevData.isDevCard(item)) continue;
      result.add(fromCardModel(item));
    }

    for (final reward in rewards) {
      if (!DevData.showDevData && DevData.isDevReward(reward)) continue;
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
          isBookmarked: _isBookmarkedMeta(reward.metadata),
          sourceReward: reward,
        ),
      );
    }

    return result;
  }
}

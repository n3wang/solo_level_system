import 'dart:math';

import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/character_stats_service.dart';

/// Rarity-weighted random draw over the card catalog for session loot.
///
/// Draws can repeat; repeats stack (`acquisitionCount`), re-applying unlock
/// semantics on the drawn card.
///
/// **Never drops [CardType.reward]** — rewards are purchase-only (Create Reward
/// / shop), never session loot.
class CardDropService {
  CardDropService._();

  static final Random _random = Random();
  static const String boxName = 'motivationItems';

  /// Relative draw weight per rarity (rarer = less likely).
  static const Map<CardRarity, double> _weights = {
    CardRarity.common: 1.0,
    CardRarity.uncommon: 0.5,
    CardRarity.rare: 0.2,
    CardRarity.epic: 0.06,
  };

  /// Draw [count] cards from the pool. Returns live box objects so callers can
  /// `recordAcquisition()` on them. Empty if the pool is empty.
  ///
  /// When [allowedStats] is provided, cards whose
  /// `CharacterStatsService.statForCard` maps to a stat outside that set are
  /// excluded — cards with no stat mapping (room/music/option/boardgame/...)
  /// are never restricted by this filter.
  static List<CardModel> draw(int count, {Set<CharacterStat>? allowedStats}) {
    if (count <= 0 || !Hive.isBoxOpen(boxName)) return const [];
    final pool = Hive.box<CardModel>(boxName).values
        .where(isDroppable)
        .where((card) => _matchesAllowedStats(card, allowedStats))
        .toList();
    if (pool.isEmpty) return const [];

    final result = <CardModel>[];
    for (var i = 0; i < count; i++) {
      final card = _weightedPick(pool);
      if (card != null) result.add(card);
    }
    return result;
  }

  /// Rewards must be purchased — never included in session loot.
  static bool isDroppable(CardModel card) {
    final wire = card.type.trim().toLowerCase();
    if (wire == CardType.reward.wire || wire.startsWith('reward')) {
      return false;
    }
    if (card.cardType == CardType.reward) return false;
    // Explicit purchase-only flags (custom / shop goals).
    final meta = card.metadata;
    if (meta['purchaseOnly'] == true || meta['isReward'] == true) {
      return false;
    }
    return true;
  }

  static bool _matchesAllowedStats(
    CardModel card,
    Set<CharacterStat>? allowedStats,
  ) {
    if (allowedStats == null) return true;
    final stat = CharacterStatsService.statForCard(card);
    if (stat == null) return true;
    return allowedStats.contains(stat);
  }

  static CardModel? _weightedPick(List<CardModel> pool) {
    var total = 0.0;
    for (final card in pool) {
      total += _weights[card.rarityTier] ?? 1.0;
    }
    if (total <= 0) return pool[_random.nextInt(pool.length)];

    var roll = _random.nextDouble() * total;
    for (final card in pool) {
      roll -= _weights[card.rarityTier] ?? 1.0;
      if (roll <= 0) return card;
    }
    return pool.last;
  }
}

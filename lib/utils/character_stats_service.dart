import 'package:solo_level_system/models/card_model.dart';

/// The six RPG ability stats, built up by acquiring cards from mapped
/// categories (see [CharacterStatsService.statForCard]).
enum CharacterStat {
  strength,
  dexterity,
  wisdom,
  constitution,
  intelligence,
  charisma;

  /// Three-letter D&D-style abbreviation (STR/DEX/WIS/CON/INT/CHA).
  String get abbreviation {
    switch (this) {
      case CharacterStat.strength:
        return 'STR';
      case CharacterStat.dexterity:
        return 'DEX';
      case CharacterStat.wisdom:
        return 'WIS';
      case CharacterStat.constitution:
        return 'CON';
      case CharacterStat.intelligence:
        return 'INT';
      case CharacterStat.charisma:
        return 'CHA';
    }
  }

  String get label {
    switch (this) {
      case CharacterStat.strength:
        return 'Strength';
      case CharacterStat.dexterity:
        return 'Dexterity';
      case CharacterStat.wisdom:
        return 'Wisdom';
      case CharacterStat.constitution:
        return 'Constitution';
      case CharacterStat.intelligence:
        return 'Intelligence';
      case CharacterStat.charisma:
        return 'Charisma';
    }
  }
}

/// Derived, combat-facing numbers computed 1:1 off the raw ability totals.
class CharacterCombatStats {
  final double attackDamage;
  final double attackSpeed;
  final double armor;
  final double maxHealth;
  final int critChancePercent;
  final int evasionChancePercent;
  final double luck;

  const CharacterCombatStats({
    required this.attackDamage,
    required this.attackSpeed,
    required this.armor,
    required this.maxHealth,
    required this.critChancePercent,
    required this.evasionChancePercent,
    required this.luck,
  });

  factory CharacterCombatStats.from(Map<CharacterStat, double> totals) {
    final intelligenceWhole = (totals[CharacterStat.intelligence] ?? 0)
        .floor();
    return CharacterCombatStats(
      attackDamage: totals[CharacterStat.strength] ?? 0,
      attackSpeed: totals[CharacterStat.dexterity] ?? 0,
      armor: totals[CharacterStat.wisdom] ?? 0,
      maxHealth: totals[CharacterStat.constitution] ?? 0,
      critChancePercent: (intelligenceWhole / 2).ceil(),
      evasionChancePercent: intelligenceWhole ~/ 2,
      luck: totals[CharacterStat.charisma] ?? 0,
    );
  }
}

/// Maps acquired cards to RPG ability stats and computes the diminishing-
/// return contribution each acquisition grants.
///
/// First acquisition of a given card grants a full point toward its mapped
/// stat; every repeat of that *same* card only grants 20% of a point.
/// Non-mapped categories (rewards, room/music/option, boardgame,
/// mythology, ...) contribute to no stat.
class CharacterStatsService {
  CharacterStatsService._();

  /// The stat a card's acquisitions build toward, or null if this card
  /// doesn't contribute to any stat.
  static CharacterStat? statForCard(CardModel card) {
    if (card.cardType == CardType.exercise) return CharacterStat.constitution;
    if (card.cardType == CardType.phy) return CharacterStat.wisdom;

    switch (card.category.trim().toLowerCase()) {
      case 'dnd5e':
        return CharacterStat.strength;
      case 'ornithography':
      case 'animals':
        return CharacterStat.dexterity;
      case 'art':
        return CharacterStat.wisdom;
      case 'floriography':
      case 'plant':
      case 'plants':
        return CharacterStat.constitution;
      case 'history':
        return CharacterStat.intelligence;
      case 'npc':
        return CharacterStat.charisma;
      default:
        return null;
    }
  }

  /// Point value of this card's *current* acquisition state: 0 if unowned,
  /// 1.0 for the first copy, +0.2 for each additional copy.
  static double contributionOf(CardModel card) {
    if (card.acquisitionCount <= 0) return 0;
    return 1.0 + 0.2 * (card.acquisitionCount - 1);
  }

  /// Point value the *next* acquisition of this card would add — used to
  /// preview the stat effect before the player commits to a rogue pick.
  static double deltaForNextAcquisition(CardModel card) {
    return card.acquisitionCount <= 0 ? 1.0 : 0.2;
  }

  /// Summed ability totals across all owned cards, grouped by mapped stat.
  static Map<CharacterStat, double> totals(Iterable<CardModel> cards) {
    final result = <CharacterStat, double>{
      for (final stat in CharacterStat.values) stat: 0,
    };
    for (final card in cards) {
      if (!card.hasAnyAcquisition) continue;
      final stat = statForCard(card);
      if (stat == null) continue;
      result[stat] = (result[stat] ?? 0) + contributionOf(card);
    }
    return result;
  }
}

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/card_model.dart';

/// Well-known setting keys raised by `option` cards.
class SettingKeys {
  SettingKeys._();
  static const String projectSlots = 'project_slots';
  static const String roomSlots = 'room_slots';
}

/// How-to content surfaced by an unlocked `guide` card on its target screen.
class GuideContent {
  final String title;
  final String body;
  final List<String> tips;

  const GuideContent({
    required this.title,
    required this.body,
    this.tips = const [],
  });
}

/// Single query point for "is X unlocked?" and "how much capacity for setting Y?".
///
/// Reads the card catalog (`motivationItems` box) and nothing else, so gated
/// screens depend on this service instead of Hive directly.
class UnlockService {
  UnlockService._();

  static const String boxName = 'motivationItems';

  static Box<CardModel>? get _box =>
      Hive.isBoxOpen(boxName) ? Hive.box<CardModel>(boxName) : null;

  /// A content target (program / set / room / music) is unlocked unless a card
  /// explicitly gates it (`unlockTargetId == targetId`) and stays unacquired.
  /// Ungated targets are unlocked by default so nothing disappears until the
  /// catalog deliberately gates it.
  static bool isUnlocked(String targetId) {
    final box = _box;
    if (box == null) return true;
    var gated = false;
    for (final card in box.values) {
      if (card.unlockTargetId == targetId) {
        gated = true;
        if (card.hasAnyAcquisition) return true;
      }
    }
    return !gated;
  }

  /// How many copies of a specific card are owned (`owned xN`).
  static int ownedCount(String cardId) {
    final box = _box;
    if (box == null) return 0;
    for (final card in box.values) {
      if (card.id == cardId) return card.acquisitionCount;
    }
    return 0;
  }

  /// Capacity for a stackable option setting:
  /// `base + Σ(acquisitionCount × capacityPerCopy)` over matching option cards.
  static int capacityFor(String settingKey, {int base = 0}) {
    final box = _box;
    if (box == null) return base;
    var total = base;
    for (final card in box.values) {
      if (card.cardType != CardType.option) continue;
      final key = card.metadata['settingKey'] ?? card.unlockTargetId;
      if (key != settingKey) continue;
      final perCopy = card.metadata['capacityPerCopy'];
      final step = perCopy is num ? perCopy.toInt() : 1;
      total += card.acquisitionCount * step;
    }
    return total;
  }

  /// How-to content for a screen, or null when no guide card is unlocked for it
  /// (in which case the screen shows no `?` control).
  static GuideContent? guideFor(String screenKey) {
    final box = _box;
    if (box == null) return null;
    for (final card in box.values) {
      if (card.cardType != CardType.guide) continue;
      final key = card.metadata['screenKey'] ?? card.unlockTargetId;
      if (key != screenKey) continue;
      if (!card.hasAnyAcquisition) continue;
      final howTo = card.metadata['howTo'];
      final tips = card.metadata['tips'];
      return GuideContent(
        title: card.title,
        body: howTo is String && howTo.trim().isNotEmpty
            ? howTo
            : card.description,
        tips: tips is List
            ? tips.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
            : const [],
      );
    }
    return null;
  }

  /// Rebuilds when the catalog changes (acquisition, seeding, edits).
  static Listenable? changes() => _box?.listenable();
}

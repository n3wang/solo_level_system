import 'package:flutter/material.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';

/// Icon for a card type wire string (or [CardType]).
IconData collectibleTypeIcon(String type) {
  switch (CardType.parse(type)) {
    case CardType.phy:
      return Icons.person_outline;
    case CardType.reward:
      return Icons.card_giftcard;
    case CardType.room:
      return Icons.weekend_outlined;
    case CardType.music:
      return Icons.music_note;
    case CardType.exercise:
      return Icons.fitness_center;
    case CardType.option:
      return Icons.tune;
    case CardType.collection:
      return Icons.diamond_outlined;
  }
}

/// Category chips as icons only (reward create / filters feel).
IconData collectibleCategoryIcon(String category) {
  switch (category.trim().toLowerCase()) {
    case 'electronics':
      return Icons.devices;
    case 'entertainment':
      return Icons.sports_esports;
    case 'food':
      return Icons.restaurant;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'activities':
      return Icons.directions_run;
    case 'tools':
      return Icons.build_outlined;
    case 'books':
      return Icons.menu_book_outlined;
    case 'health':
      return Icons.favorite_outline;
    case 'travel':
      return Icons.flight_takeoff;
    case 'lofi':
    case 'music':
      return Icons.music_note;
    case 'room':
      return Icons.weekend_outlined;
    default:
      return Icons.category_outlined;
  }
}

const List<String> kRewardCategories = [
  'general',
  'electronics',
  'entertainment',
  'food',
  'shopping',
  'activities',
  'tools',
  'books',
  'health',
  'travel',
];

/// Catalog type filters for Cards hub (no `all` — pick a specific type).
const List<String> kCollectibleTypeFilters = [
  'phy',
  'collection',
  'reward',
  'room',
  'music',
  'exercise',
  'option',
];

/// Special filter value for bookmarked cards (hub + overview).
const String kCollectibleBookmarkFilter = 'bookmarked';

/// Overview acquired list may still filter with `all` inside the week window.
const List<String> kCollectibleOverviewTypeFilters = [
  'all',
  kCollectibleBookmarkFilter,
  ...kCollectibleTypeFilters,
];

/// Whether unowned catalog art/copy should be shown in full (test/demo).
bool revealCollectibleContents(
  CatalogCard card, {
  bool acquiredReveal = false,
}) {
  if (acquiredReveal) return true;
  if (AppEnvironment.revealUnacquiredCardDetails) return true;
  return card.isAcquired;
}

/// Spoiler copy for locked cards (Pokemon TCG-style acquire-to-reveal).
String collectibleAcquirePrompt(CardType type) {
  switch (type) {
    case CardType.music:
      return 'Acquire to listen.';
    case CardType.phy:
      return 'Acquire to discover.';
    case CardType.exercise:
      return 'Acquire to unlock.';
    case CardType.room:
    case CardType.reward:
    case CardType.collection:
    case CardType.option:
      return 'Acquire to view.';
  }
}

/// Ownership / cost copy used on tiles and overlays.
String collectibleCardPointsText(CatalogCard card) {
  if (card.isAcquired) {
    return card.acquisitionCount > 1
        ? 'owned x${card.acquisitionCount}'
        : 'owned';
  }
  return '${card.pointsCost}';
}

/// Catalog descriptions use `;` as a paragraph break.
List<String> collectibleDescriptionParagraphs(String raw) {
  return raw
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

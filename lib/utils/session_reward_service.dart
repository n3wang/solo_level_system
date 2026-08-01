import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_drop_service.dart';
import 'package:solo_level_system/utils/motivation_points_service.dart';

/// What kind of session produced the reward (drives the transaction source).
enum SessionKind { focus, workout }

/// Result of a completed session: points earned + cards dropped.
class SessionLoot {
  final int points;
  final int minutes;
  final SessionKind kind;
  final List<CardModel> cards;

  const SessionLoot({
    required this.points,
    required this.minutes,
    required this.kind,
    required this.cards,
  });

  bool get isEmpty => points == 0 && cards.isEmpty;
}

/// Grants the "any session complete" rewards from the design:
/// **+1 point / minute**. Focus sessions always drop **1 card** (rarity
/// scaling by duration/difficulty comes later). Workouts still use
/// **⌊minutes / 10⌋ cards (min 1)**.
///
/// No XP, no level-ups, no level bonus — points + cards only.
class SessionRewardService {
  SessionRewardService._();

  static const int pointsPerMinute = 1;
  static const int minutesPerCard = 10;

  static SessionLoot grant({
    required int minutes,
    required SessionKind kind,
    UserProgressModel? progress,
    int? cardCountOverride,
  }) {
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final points = safeMinutes * pointsPerMinute;

    final wallet = progress ?? _progress();
    if (wallet != null) {
      try {
        wallet.addPoints(points);
        if (wallet.isInBox) {
          wallet.save();
        } else if (Hive.isBoxOpen('userProgress')) {
          Hive.box<UserProgressModel>('userProgress').put('progress', wallet);
        }
      } catch (e) {
        // Points grant should not abort the rest of session completion.
        assert(() {
          // ignore: avoid_print
          print('SessionRewardService points save failed: $e');
          return true;
        }());
      }
    }
    MotivationPointsService.recordEarned(
      amount: points,
      source: '${kind.name}_session',
      metadata: {'minutes': safeMinutes},
    );

    // Focus: override or default 1. Workout keeps minutes-based count.
    final cardCount = cardCountOverride ??
        (kind == SessionKind.focus
            ? 1
            : (safeMinutes ~/ minutesPerCard).clamp(1, 1 << 20));
    // Defense in depth: never grant reward cards from session loot.
    final drops = CardDropService.draw(cardCount)
        .where(CardDropService.isDroppable)
        .toList();
    for (final card in drops) {
      try {
        card.recordAcquisition();
        if (card.isInBox) card.save();
      } catch (e) {
        assert(() {
          // ignore: avoid_print
          print('SessionRewardService card save failed: $e');
          return true;
        }());
      }
    }

    return SessionLoot(
      points: points,
      minutes: safeMinutes,
      kind: kind,
      cards: drops,
    );
  }

  /// Draws cards without acquiring (for rogue pick UI).
  static List<CardModel> drawCards(int count) {
    return CardDropService.draw(count)
        .where(CardDropService.isDroppable)
        .toList();
  }

  /// Grants already-drawn cards (e.g. rogue pick) without drawing again.
  static SessionLoot grantDrawnCards({
    required int minutes,
    required SessionKind kind,
    required List<CardModel> cards,
    UserProgressModel? progress,
    bool grantPoints = true,
  }) {
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final points = grantPoints ? safeMinutes * pointsPerMinute : 0;
    final wallet = progress ?? _progress();
    if (wallet != null && points > 0) {
      try {
        wallet.addPoints(points);
        if (wallet.isInBox) {
          wallet.save();
        } else if (Hive.isBoxOpen('userProgress')) {
          Hive.box<UserProgressModel>('userProgress').put('progress', wallet);
        }
      } catch (_) {}
    }
    if (points > 0) {
      MotivationPointsService.recordEarned(
        amount: points,
        source: '${kind.name}_session',
        metadata: {'minutes': safeMinutes, 'rogue': true},
      );
    }

    final granted = <CardModel>[];
    for (final card in cards) {
      try {
        card.recordAcquisition();
        if (card.isInBox) card.save();
        granted.add(card);
      } catch (_) {}
    }

    return SessionLoot(
      points: points,
      minutes: safeMinutes,
      kind: kind,
      cards: granted,
    );
  }

  static UserProgressModel? _progress() {
    if (!Hive.isBoxOpen('userProgress')) return null;
    return Hive.box<UserProgressModel>('userProgress').get('progress');
  }
}

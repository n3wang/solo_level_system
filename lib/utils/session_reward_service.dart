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
/// **+1 point / minute** and **⌊minutes / 10⌋ random cards (min 1)**.
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
  }) {
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final points = safeMinutes * pointsPerMinute;

    final wallet = progress ?? _progress();
    if (wallet != null) {
      wallet.addPoints(points);
      wallet.save();
    }
    MotivationPointsService.recordEarned(
      amount: points,
      source: '${kind.name}_session',
      metadata: {'minutes': safeMinutes},
    );

    final cardCount = (safeMinutes ~/ minutesPerCard).clamp(1, 1 << 20);
    // Defense in depth: never grant reward cards from session loot.
    final drops = CardDropService.draw(cardCount)
        .where(CardDropService.isDroppable)
        .toList();
    for (final card in drops) {
      card.recordAcquisition();
      card.save();
    }

    return SessionLoot(
      points: points,
      minutes: safeMinutes,
      kind: kind,
      cards: drops,
    );
  }

  static UserProgressModel? _progress() {
    if (!Hive.isBoxOpen('userProgress')) return null;
    return Hive.box<UserProgressModel>('userProgress').get('progress');
  }
}

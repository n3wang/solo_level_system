import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';

/// Outcome of an acquire attempt, for the UI to surface.
class AcquisitionResult {
  final bool success;
  final String message;

  /// New owned/purchased count after a successful acquire.
  final int? newCount;

  const AcquisitionResult(this.success, this.message, {this.newCount});
}

/// Owns the buy/acquire transaction: spend points, then mark the card acquired
/// (or the reward purchased). Kept out of the widget layer so the hub screen is
/// presentation-only. Acquiring a card stacks (`acquisitionCount`), which the
/// [UnlockService] then reflects as raised capacity / unlocked content.
///
/// Acquiring a **room** also grants that room's bundled music tracks (matching
/// `metadata.trackRegex`) without an extra points charge.
class CardAcquisitionService {
  CardAcquisitionService._();

  static const String _cardsBox = 'motivationItems';

  static Future<AcquisitionResult> acquireCard(
    CardModel card,
    UserProgressModel progress,
  ) async {
    if (!progress.spendPoints(card.pointsCost)) {
      return const AcquisitionResult(false, 'Not enough points');
    }
    card.recordAcquisition();
    await card.save();

    var bonusMsg = '';
    if (card.cardType == CardType.room) {
      final bundled = await grantRoomMusicBundle(card);
      if (bundled > 0) {
        bonusMsg =
            ' (+$bundled track${bundled == 1 ? '' : 's'} + visuals)';
      } else {
        bonusMsg = ' (+ visuals)';
      }
    }

    return AcquisitionResult(
      true,
      card.acquisitionCount > 1
          ? 'Acquired ${card.title} (${card.acquisitionCount}x)$bonusMsg'
          : 'Acquired ${card.title}$bonusMsg',
      newCount: card.acquisitionCount,
    );
  }

  /// Unlocks music cards whose filenames match the room's `trackRegex`.
  /// Does not spend points — they come with the room.
  static Future<int> grantRoomMusicBundle(CardModel roomCard) async {
    final raw = roomCard.metadata['trackRegex'];
    if (raw is! String || raw.trim().isEmpty) return 0;
    final RegExp regex;
    try {
      regex = RegExp(raw);
    } catch (_) {
      return 0;
    }

    if (!Hive.isBoxOpen(_cardsBox)) {
      await Hive.openBox<CardModel>(_cardsBox);
    }
    final box = Hive.box<CardModel>(_cardsBox);
    var granted = 0;
    for (final other in box.values) {
      if (other.cardType != CardType.music) continue;
      final target = other.unlockTargetId;
      if (target == null || !target.startsWith('music:')) continue;
      final filename = target.substring('music:'.length);
      if (!regex.hasMatch(filename)) continue;
      if (other.hasAnyAcquisition) continue;
      other.recordAcquisition();
      await other.save();
      granted++;
    }
    return granted;
  }

  static AcquisitionResult acquireReward(
    RewardModel reward,
    UserProgressModel progress,
  ) {
    if (!reward.canBePurchased) {
      return const AcquisitionResult(
        false,
        'This reward is no longer available',
      );
    }
    if (!progress.spendPoints(reward.pointsCost)) {
      return const AcquisitionResult(false, 'Not enough points');
    }
    reward.purchase();
    return AcquisitionResult(
      true,
      'Acquired ${reward.title}',
      newCount: reward.timesPurchased,
    );
  }
}

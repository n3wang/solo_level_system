import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/session_reward_service.dart';
import 'package:solo_level_system/widgets/cards/acquired_card_toast.dart';

/// Post-session loot: non-blocking bottom-right toasts for each dropped card.
/// Tap a toast to open the acquired card modal; otherwise it dismisses after 3s.
///
/// Returns immediately so the session UI is not blocked while toasts play out.
Future<void> showSessionLootDialog(
  BuildContext context,
  SessionLoot loot,
) async {
  if (!context.mounted || loot.cards.isEmpty) return;

  UserProgressModel progress = UserProgressModel();
  if (Hive.isBoxOpen('userProgress')) {
    progress =
        Hive.box<UserProgressModel>('userProgress').get('progress') ?? progress;
  }

  final catalog = loot.cards.map(CardRepository.fromCardModel).toList();
  // Fire-and-forget: do not block focus/workout completion on toast timeouts.
  unawaited(
    showAcquiredCardToasts(
      context: context,
      cards: catalog,
      userProgress: progress,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/session_reward_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';

/// Post-session loot: points summary, then each dropped card using the shared
/// collectible modal with "Acquired" + rarity/copy banners.
Future<void> showSessionLootDialog(
  BuildContext context,
  SessionLoot loot,
) async {
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => _SessionPointsDialog(loot: loot),
  );

  if (!context.mounted || loot.cards.isEmpty) return;

  UserProgressModel progress = UserProgressModel();
  if (Hive.isBoxOpen('userProgress')) {
    progress =
        Hive.box<UserProgressModel>('userProgress').get('progress') ?? progress;
  }

  final catalog = loot.cards.map(CardRepository.fromCardModel).toList();
  await showAcquiredCardReveals(
    context: context,
    cards: catalog,
    userProgress: progress,
  );
}

class _SessionPointsDialog extends StatelessWidget {
  final SessionLoot loot;

  const _SessionPointsDialog({required this.loot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.tertiary),
          const SizedBox(width: AppUiSizes.sm),
          const Text('Session Reward'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+${loot.points} points  ·  ${loot.minutes} min',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: AppUiSizes.md),
            Text(
              loot.cards.isEmpty
                  ? 'No cards dropped this time.'
                  : '${loot.cards.length} card${loot.cards.length == 1 ? '' : 's'} dropped — tap Continue to reveal.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loot.cards.isEmpty ? 'Nice!' : 'Continue'),
        ),
      ],
    );
  }
}

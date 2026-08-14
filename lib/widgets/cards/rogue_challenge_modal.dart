import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/character_stats_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';

class RogueChallengeOption {
  const RogueChallengeOption({
    required this.card,
    required this.challenge,
  });

  final CardModel card;
  final String challenge;
}

class RogueChallengePick {
  const RogueChallengePick({
    required this.card,
    required this.challenge,
  });

  final CardModel card;
  final String challenge;
}

/// Fullscreen dimmed pick: only the two cards + challenges. Tap outside to skip.
Future<RogueChallengePick?> showRogueChallengeModal({
  required BuildContext context,
  required List<RogueChallengeOption> options,
  required UserProgressModel userProgress,
}) {
  assert(options.length == 2);
  return showGeneralDialog<RogueChallengePick>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss rogue pick',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _RogueChallengeOverlay(
        options: options,
        userProgress: userProgress,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Builds two unique cards + two unique challenges from the pools.
List<RogueChallengeOption> buildRogueOptions({
  required List<CardModel> cards,
  required List<String> challenges,
  Random? random,
}) {
  final rng = random ?? Random();
  final cardPool = List<CardModel>.from(cards)..shuffle(rng);
  final challengePool = challenges
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..shuffle(rng);

  if (cardPool.length < 2 || challengePool.length < 2) return const [];

  return [
    RogueChallengeOption(card: cardPool[0], challenge: challengePool[0]),
    RogueChallengeOption(card: cardPool[1], challenge: challengePool[1]),
  ];
}

class _RogueChallengeOverlay extends StatelessWidget {
  const _RogueChallengeOverlay({
    required this.options,
    required this.userProgress,
  });

  final List<RogueChallengeOption> options;
  final UserProgressModel userProgress;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUiSizes.lg,
            vertical: AppUiSizes.xl,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppUiSizes.md;
              final challengeStyle = Theme.of(context).textTheme.titleMedium
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  );
              final lineHeight =
                  (challengeStyle?.fontSize ?? 16) *
                  (challengeStyle?.height ?? 1.25);
              // Always reserve exactly 2 text rows (+ padding + gap under card).
              final challengeBoxHeight =
                  lineHeight * 2 + AppUiSizes.sm * 2;
              final labelBlock = challengeBoxHeight + AppUiSizes.md;
              final maxCardWidth = (constraints.maxWidth - gap) / 2;
              final maxCardHeight =
                  maxCardWidth / CollectibleCardLayout.aspectRatio;
              final availableForCard = (constraints.maxHeight - labelBlock)
                  .clamp(96.0, 10000.0);
              final cardHeight = min(maxCardHeight, availableForCard);
              final cardWidth = cardHeight * CollectibleCardLayout.aspectRatio;

              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _buildOption(
                        context,
                        options[i],
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        challengeStyle: challengeStyle,
                        challengeBoxHeight: challengeBoxHeight,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    RogueChallengeOption option, {
    required double cardWidth,
    required double cardHeight,
    required TextStyle? challengeStyle,
    required double challengeBoxHeight,
  }) {
    final catalog = CardRepository.fromCardModel(option.card);
    final stat = CharacterStatsService.statForCard(option.card);
    final statDelta = stat == null
        ? null
        : CharacterStatsService.deltaForNextAcquisition(option.card);
    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: CollectibleCardLayout.aspectRatio,
                  child: CollectibleCardTile(
                    card: catalog,
                    forceRevealContents: true,
                    availablePoints: userProgress.availablePoints,
                    onTap: () {
                      Navigator.of(context).pop(
                        RogueChallengePick(
                          card: option.card,
                          challenge: option.challenge,
                        ),
                      );
                    },
                  ),
                ),
                if (stat != null && statDelta != null)
                  Positioned(
                    top: AppUiSizes.xs,
                    right: AppUiSizes.xs,
                    child: _StatEffectBadge(stat: stat, delta: statDelta),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppUiSizes.md),
          Container(
            width: double.infinity,
            height: challengeBoxHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppUiSizes.md,
              vertical: AppUiSizes.sm,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
            ),
            child: Text(
              option.challenge,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: challengeStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing the stat this pick would raise, e.g. "STR +1" for a
/// first-time acquisition or "STR +0.2" for a repeat.
class _StatEffectBadge extends StatelessWidget {
  const _StatEffectBadge({required this.stat, required this.delta});

  final CharacterStat stat;
  final double delta;

  String get _formattedDelta =>
      delta == delta.roundToDouble()
          ? delta.toInt().toString()
          : delta.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppUiSizes.sm,
          vertical: 2,
        ),
        child: Text(
          '${stat.abbreviation} +$_formattedDelta',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

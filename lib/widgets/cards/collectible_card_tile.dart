import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_art.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_chrome.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_meta.dart';

/// Standard grid / overview tile. Category is an icon; card-type icons are
/// omitted so the art can read as the card face.
class CollectibleCardTile extends StatelessWidget {
  final CatalogCard card;
  final VoidCallback? onTap;
  final int? availablePoints;
  final String? overrideLocalImagePath;

  /// Always show real art (e.g. create-reward preview).
  final bool forceRevealContents;

  const CollectibleCardTile({
    super.key,
    required this.card,
    this.onTap,
    this.availablePoints,
    this.overrideLocalImagePath,
    this.forceRevealContents = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAfford = availablePoints == null
        ? true
        : availablePoints! >= card.pointsCost;
    final revealed = forceRevealContents || revealCollectibleContents(card);
    final fullBleed =
        revealed && CollectibleCardLayout.isFullBleedAsset(card.imageAsset);
    final radius = BorderRadius.circular(AppUiSizes.radiusMd);

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: fullBleed
          ? _buildFullBleedFace(
              context,
              scheme: scheme,
              radius: radius,
              revealed: revealed,
              canAfford: canAfford,
            )
          : _buildSquareFace(
              context,
              scheme: scheme,
              radius: radius,
              revealed: revealed,
              canAfford: canAfford,
            ),
    );
  }

  Widget _buildSquareFace(
    BuildContext context, {
    required ColorScheme scheme,
    required BorderRadius radius,
    required bool revealed,
    required bool canAfford,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppUiSizes.sm),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
        color: scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CollectibleCardStatusIcons(card: card, revealed: revealed),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artSize = CollectibleCardLayout.artSizeForWidth(
                  constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                );
                return Center(
                  child: CollectibleCardArt(
                    card: card,
                    size: artSize,
                    overrideLocalImagePath: overrideLocalImagePath,
                    revealContents: revealed,
                  ),
                );
              },
            ),
          ),
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppUiSizes.xxs),
          Row(
            children: [
              if (card.isProgram && card.durationSeconds > 0) ...[
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 2),
                Text(
                  card.formattedDuration,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
              const Spacer(),
              CollectibleCardPointsLabel(card: card, canAfford: canAfford),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullBleedFace(
    BuildContext context, {
    required ColorScheme scheme,
    required BorderRadius radius,
    required bool revealed,
    required bool canAfford,
  }) {
    return Material(
      color: CollectibleCardLayout.isPngAsset(card.imageAsset)
          ? Colors.white
          : Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CollectibleCardArt(
            card: card,
            expand: true,
            overrideLocalImagePath: overrideLocalImagePath,
            revealContents: revealed,
          ),
          Positioned(
            top: AppUiSizes.xs,
            right: AppUiSizes.xs,
            child: CollectibleCardStatusIcons(
              card: card,
              revealed: revealed,
              chip: true,
            ),
          ),
          Positioned(
            left: AppUiSizes.xs,
            right: AppUiSizes.xs,
            bottom: AppUiSizes.xs,
            child: Row(
              children: [
                Flexible(child: CollectibleCardTitlePill(card.title)),
                const SizedBox(width: AppUiSizes.xs),
                CollectibleCardPointsLabel(
                  card: card,
                  canAfford: canAfford,
                  overArt: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

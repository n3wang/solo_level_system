import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_meta.dart';

/// Title / category capsule used on full-bleed card faces.
class CollectibleCardTitlePill extends StatelessWidget {
  final String text;
  final bool emphasis;
  final TextStyle? style;

  const CollectibleCardTitlePill(
    this.text, {
    super.key,
    this.emphasis = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasis
            ? Colors.white.withValues(alpha: 0.94)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            style ??
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: emphasis ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Cost / owned label. Set [overArt] on full-bleed tiles so the number sits
/// on the image with no pill background.
class CollectibleCardPointsLabel extends StatelessWidget {
  final CatalogCard card;
  final bool canAfford;
  final bool overArt;

  const CollectibleCardPointsLabel({
    super.key,
    required this.card,
    required this.canAfford,
    this.overArt = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = card.isAcquired
        ? (overArt ? Colors.white : scheme.onSurface.withValues(alpha: 0.65))
        : canAfford
        ? scheme.primary
        : scheme.error;
    return Text(
      collectibleCardPointsText(card),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        shadows: overArt
            ? const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Category / lock / bookmark cluster shared by hub tiles.
class CollectibleCardStatusIcons extends StatelessWidget {
  final CatalogCard card;
  final bool revealed;
  final bool chip;

  const CollectibleCardStatusIcons({
    super.key,
    required this.card,
    required this.revealed,
    this.chip = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icons = <Widget>[
      if (revealed)
        Icon(
          collectibleCategoryIcon(card.category),
          size: 16,
          color: scheme.onSurface.withValues(alpha: 0.45),
        ),
      if (!card.isAcquired)
        Icon(
          Icons.lock_outline,
          size: 14,
          color: scheme.onSurface.withValues(alpha: 0.35),
        ),
      if (card.isBookmarked)
        Icon(Icons.bookmark, size: 14, color: scheme.primary),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();

    final row = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppUiSizes.xs),
          icons[i],
        ],
      ],
    );
    if (!chip) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: row,
      ),
    );
  }
}

/// Modal description body: `;` in catalog copy becomes a new paragraph
/// with a blank line between blocks.
class CollectibleDescriptionText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CollectibleDescriptionText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final paragraphs = collectibleDescriptionParagraphs(text);
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: AppUiSizes.md),
          Text(paragraphs[i], style: style),
        ],
      ],
    );
  }
}

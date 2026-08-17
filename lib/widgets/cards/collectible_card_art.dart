import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_meta.dart';
import 'package:solo_level_system/widgets/game_icon_widget.dart';

/// Generic unrevealed-card art: same outlined help icon used as the type
/// fallback (large grey `?` in a circle).
class CollectibleMysteryArt extends StatelessWidget {
  final double size;

  const CollectibleMysteryArt({
    super.key,
    this.size = CollectibleCardLayout.tileArtSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.help_outline,
        size: size * 0.75,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Shared art for a [CatalogCard] (sprite, asset, file, or type icon).
class CollectibleCardArt extends StatelessWidget {
  final CatalogCard card;
  final double size;
  final String? overrideLocalImagePath;

  /// When false, shows [CollectibleMysteryArt] instead of real art.
  final bool revealContents;

  /// Fill the parent box (portrait full-bleed). [size] is only used for
  /// square fallbacks (mystery / type icon / program).
  final bool expand;

  /// Image fit when painting bitmap art. Ignored for program / mystery art.
  final BoxFit fit;

  /// When null, square art uses [CollectibleCardLayout.artRadius]; expanded
  /// art is unclipped so the parent card can clip.
  final BorderRadius? borderRadius;

  const CollectibleCardArt({
    super.key,
    required this.card,
    this.size = CollectibleCardLayout.tileArtSize,
    this.overrideLocalImagePath,
    this.revealContents = true,
    this.expand = false,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!expand) {
      return _buildArt(context, width: size, height: size, iconSize: size);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final iconSize = min(width, height);
        return _buildArt(
          context,
          width: width,
          height: height,
          iconSize: iconSize,
        );
      },
    );
  }

  Widget _buildArt(
    BuildContext context, {
    required double width,
    required double height,
    required double iconSize,
  }) {
    if (!revealContents) {
      return Center(child: CollectibleMysteryArt(size: iconSize));
    }

    if (card.isProgram) {
      return Center(
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: _clipArt(_buildProgramArt(context, iconSize)),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      collectibleTypeIcon(card.typeWire),
      size: iconSize * 0.75,
      color: scheme.onSurface.withValues(alpha: 0.5),
    );

    final local = overrideLocalImagePath ?? card.localImagePath;
    if (local != null && local.isNotEmpty && !kIsWeb) {
      final file = File(local);
      if (file.existsSync()) {
        return _paintRaster(
          Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          ),
          path: local,
        );
      }
    }

    final index = card.imageIndex;
    if (index != null && index > 0) {
      return _paintRaster(
        MotivationIconWidget(
          imageIndex: index,
          size: iconSize,
          placeholder: fallback,
        ),
        png: true,
      );
    }

    final asset = card.imageAsset;
    if (asset != null && asset.isNotEmpty) {
      return _paintRaster(
        Image.asset(
          asset,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        ),
        path: asset,
      );
    }

    return Center(child: fallback);
  }

  /// PNG catalog art is anti-aliased for a white page; fill behind it so
  /// transparent fringes don't sit on a dark card.
  Widget _paintRaster(Widget child, {String? path, bool png = false}) {
    final useWhite = png || CollectibleCardLayout.isPngAsset(path);
    return _clipArt(
      useWhite ? ColoredBox(color: Colors.white, child: child) : child,
    );
  }

  Widget _clipArt(Widget child) {
    final rotated = _applyImageRotation(child);
    final radius =
        borderRadius ??
        (expand
            ? BorderRadius.zero
            : BorderRadius.circular(CollectibleCardLayout.artRadius));
    if (radius == BorderRadius.zero) return rotated;
    return ClipRRect(borderRadius: radius, child: rotated);
  }

  /// CSV page tokens like `258r` seed [CatalogCard.imageRotateDegrees] (90° CW).
  Widget _applyImageRotation(Widget child) {
    final degrees = card.imageRotateDegrees % 360;
    if (degrees == 0) return child;
    if (degrees % 90 == 0) {
      return RotatedBox(quarterTurns: (degrees ~/ 90) % 4, child: child);
    }
    return Transform.rotate(angle: degrees * pi / 180, child: child);
  }

  /// Builds program card art: large duration number with exercise icons in corner.
  Widget _buildProgramArt(BuildContext context, double artSize) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = (card.durationSeconds / 60).round();
    final exerciseImages = card.exerciseImages.take(3).toList();
    final thumbSize = artSize * 0.18;

    return SizedBox(
      width: artSize,
      height: artSize,
      child: Stack(
        children: [
          Center(
            child: Text(
              '$minutes',
              style: TextStyle(
                fontSize: artSize * 0.55,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
                height: 1,
              ),
            ),
          ),
          if (exerciseImages.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final imgPath in exerciseImages)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.asset(
                          imgPath,
                          width: thumbSize,
                          height: thumbSize,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.fitness_center,
                            size: thumbSize * 0.8,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

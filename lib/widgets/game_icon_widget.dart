import 'package:flutter/material.dart';

/// Displays a motivation / board-game icon by its catalog number.
///
/// Icons are individual pre-sliced 64×64 PNGs under
/// `assets/images/icon/c64x64_sliced/`, named by their 1-based catalog number
/// (the `number` column in `assets/data/cards_catalog.csv`, stored on a card
/// as [imageIndex]). This replaces the former `motivation_64` spritesheet —
/// each icon is now its own asset file rather than a slot in one texture.
///
/// ```dart
/// MotivationIconWidget(imageIndex: 1, size: 64) // Codenames
/// ```
class MotivationIconWidget extends StatelessWidget {
  static const String slicedBasePath = 'assets/images/icon/c64x64_sliced';

  /// 1-based catalog number — the CSV `number` / card `imageIndex`.
  final int imageIndex;
  final double? size;
  final Color? backgroundColor;

  /// Shown when the sliced asset for [imageIndex] is missing.
  final Widget? placeholder;

  const MotivationIconWidget({
    super.key,
    required this.imageIndex,
    this.size,
    this.backgroundColor,
    this.placeholder,
  });

  /// Asset path for a given 1-based catalog [number].
  static String assetPathFor(int number) => '$slicedBasePath/$number.png';

  @override
  Widget build(BuildContext context) {
    Widget image(double s) => Image.asset(
          assetPathFor(imageIndex),
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              placeholder ?? const SizedBox.shrink(),
        );

    if (size != null) {
      return RepaintBoundary(
        child: ColoredBox(
          color: backgroundColor ?? Colors.transparent,
          child: image(size!),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.biggest.shortestSide;
          return ColoredBox(
            color: backgroundColor ?? Colors.transparent,
            child: image(s),
          );
        },
      ),
    );
  }
}

import 'package:solo_level_system/constants/app_ui_sizes.dart';

/// Shared layout for catalog collectible cards (hub tiles, create preview,
/// overview tiles, and detail art frame).
class CollectibleCardLayout {
  CollectibleCardLayout._();

  /// Portrait trading-card ratio (width / height) matching 250×360 and
  /// 128×185 catalog scans. Used by hub tiles, toasts, and the detail modal.
  static const double aspectRatio = 250 / 360;

  /// Detail-modal card ratio. Same as [aspectRatio].
  static const double modalAspectRatio = aspectRatio;

  /// Target width of the detail card as a fraction of screen width.
  static const double detailCardWidthFraction = 0.88;

  /// Floor for left/right screen margin around the detail card.
  static const double detailCardMinMargin = 16;

  /// Inset on each side of tile art as a fraction of the card content width.
  /// Art width ≈ card width × (1 − 2 × this).
  static const double artMarginFraction = 0.10;

  /// Asset paths whose encoded `WxH` is ~0.69 (e.g. `c128x185`, `npcx250x360`).
  static final RegExp _pixelSizeToken = RegExp(r'(\d+)\s*[xX]\s*(\d+)');

  /// True when [imageAsset] is a portrait trading-card scan that should
  /// full-bleed the 0.69 detail card. Square icons (64×64, 128×128, workouts)
  /// return false.
  static bool isFullBleedAsset(String? imageAsset) {
    if (imageAsset == null || imageAsset.isEmpty) return false;
    for (final match in _pixelSizeToken.allMatches(imageAsset)) {
      final width = int.tryParse(match.group(1)!);
      final height = int.tryParse(match.group(2)!);
      if (width == null || height == null || height <= 0) continue;
      final ratio = width / height;
      if (ratio >= 0.64 && ratio <= 0.74) return true;
    }
    return false;
  }

  /// PNG scans (c128x185, npc portraits, sliced icons) were drawn on white.
  static bool isPngAsset(String? imageAsset) {
    if (imageAsset == null || imageAsset.isEmpty) return false;
    return imageAsset.toLowerCase().endsWith('.png');
  }

  /// Corner radius for card art — same as the tile card chrome.
  static const double artRadius = AppUiSizes.radiusMd;

  /// Preferred tile art size inside the grid cell (fallback when unconstrained).
  static const double tileArtSize = 64;

  /// Preferred art size in the detail / create modal preview.
  static const double modalArtSize = 148;

  /// Default modal width for the shared card detail dialog.
  static const double detailModalWidth = 340;

  /// Fraction of screen height for the shared card detail dialog.
  static const double detailModalHeightFactor = 0.7;

  /// Square art size that fills [contentWidth] minus [artMarginFraction] on
  /// each side, capped by [maxHeight] when provided.
  static double artSizeForWidth(double contentWidth, {double? maxHeight}) {
    final sized = contentWidth * (1.0 - 2.0 * artMarginFraction);
    if (maxHeight == null) return sized;
    return sized > maxHeight ? maxHeight : sized;
  }
}

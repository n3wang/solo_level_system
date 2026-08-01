import 'package:solo_level_system/constants/app_ui_sizes.dart';

/// Shared layout for catalog collectible cards (hub tiles, create preview,
/// overview tiles, and detail art frame).
class CollectibleCardLayout {
  CollectibleCardLayout._();

  /// Portrait trading-card ratio (width / height).
  static const double aspectRatio = 0.72;

  /// Inset on each side of tile art as a fraction of the card content width.
  /// Art width ≈ card width × (1 − 2 × this).
  static const double artMarginFraction = 0.10;

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

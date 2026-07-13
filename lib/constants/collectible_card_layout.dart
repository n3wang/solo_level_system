/// Shared layout for catalog collectible cards (hub tiles, create preview,
/// overview tiles, and detail art frame).
class CollectibleCardLayout {
  CollectibleCardLayout._();

  /// Portrait trading-card ratio (width / height).
  static const double aspectRatio = 0.72;

  /// Preferred tile art size inside the grid cell.
  static const double tileArtSize = 64;

  /// Preferred art size in the detail / create modal preview.
  static const double modalArtSize = 148;

  /// Default modal width for the shared card detail dialog.
  static const double detailModalWidth = 340;

  /// Fraction of screen height for the shared card detail dialog.
  static const double detailModalHeightFactor = 0.7;
}

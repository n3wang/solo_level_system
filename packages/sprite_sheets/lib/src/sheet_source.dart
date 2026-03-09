/// Declares a spritesheet asset to be loaded by [SpriteSheets.init].
class SheetSource {
  /// Path to the image asset (e.g. `'assets/icons_32px.png'`).
  final String assetPath;

  /// Tile width in pixels. If omitted, parsed from the filename convention.
  final int? tileWidth;

  /// Tile height in pixels. If omitted, parsed from the filename convention
  /// (defaults to [tileWidth] for square tiles).
  final int? tileHeight;

  /// Path to the CSV manifest. If omitted, inferred from [assetPath]
  /// by replacing the extension with `.csv`.
  final String? csvPath;

  const SheetSource._({
    required this.assetPath,
    this.tileWidth,
    this.tileHeight,
    this.csvPath,
  });

  /// Asset-based sheet.
  ///
  /// If [tileWidth]/[tileHeight] are not provided, they are parsed from the
  /// filename convention (`{name}_{W}px.ext` or `{name}_{W}x{H}px.ext`).
  ///
  /// ```dart
  /// // Convention-based (tile size from filename)
  /// SheetSource.asset('assets/icons_32px.png')
  ///
  /// // Explicit override for legacy/third-party sheets
  /// SheetSource.asset(
  ///   'assets/old_sheet.png',
  ///   tileWidth: 48,
  ///   tileHeight: 48,
  ///   csv: 'assets/old_sheet_manifest.csv',
  /// )
  /// ```
  factory SheetSource.asset(
    String path, {
    int? tileWidth,
    int? tileHeight,
    String? csv,
  }) {
    return SheetSource._(
      assetPath: path,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      csvPath: csv,
    );
  }

  /// Auto-discover sheets within [directory] from a flat list of [assetPaths].
  ///
  /// Each `.png` / `.webp` file inside [directory] that matches the naming
  /// convention becomes a [SheetSource]. Pass the full asset path list from
  /// your asset bundle manifest.
  ///
  /// ```dart
  /// await SpriteSheets.init(
  ///   sheets: SheetSource.discover('assets/sprites/', allAssetPaths),
  /// );
  /// ```
  static List<SheetSource> discover(String directory, List<String> assetPaths) {
    final prefix = directory.endsWith('/') ? directory : '$directory/';
    return assetPaths
        .where((p) =>
            p.startsWith(prefix) &&
            (p.endsWith('.png') || p.endsWith('.webp')))
        .map((p) => SheetSource.asset(p))
        .toList();
  }
}

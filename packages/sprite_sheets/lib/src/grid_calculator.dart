/// Immutable result of a grid calculation.
class GridInfo {
  final int columns;
  final int rows;
  final int totalSlots;
  final int tileWidth;
  final int tileHeight;
  final int remainderX;
  final int remainderY;

  const GridInfo({
    required this.columns,
    required this.rows,
    required this.totalSlots,
    required this.tileWidth,
    required this.tileHeight,
    required this.remainderX,
    required this.remainderY,
  });

  bool get hasRemainder => remainderX > 0 || remainderY > 0;
}

class GridResult {
  final GridInfo info;
  final List<String> warnings;

  const GridResult({required this.info, required this.warnings});
}

/// Thrown when the image is too small for even one tile.
class InvalidGridException implements Exception {
  final String message;
  const InvalidGridException(this.message);

  @override
  String toString() => message;
}

/// Calculates grid dimensions from image size and tile size.
/// All validation and math is derived — never ask the developer to declare counts.
class GridCalculator {
  static GridResult calculate({
    required int imageWidth,
    required int imageHeight,
    required int tileWidth,
    required int tileHeight,
    required String sheetName,
  }) {
    if (imageWidth < tileWidth || imageHeight < tileHeight) {
      throw InvalidGridException(
        '[SpriteSheet] ERROR: \'$sheetName\' is ${imageWidth}x$imageHeight '
        'but tile size is ${tileWidth}x$tileHeight.\n'
        '  → Image must be at least ${tileWidth}x$tileHeight to contain one tile.\n'
        '  → This sheet will not be loaded.',
      );
    }

    final columns = imageWidth ~/ tileWidth;
    final rows = imageHeight ~/ tileHeight;
    final remainderX = imageWidth % tileWidth;
    final remainderY = imageHeight % tileHeight;

    final warnings = <String>[];

    if (remainderX > 0) {
      warnings.add(
        '[SpriteSheet] WARNING: \'$sheetName\' width ($imageWidth) is not a '
        'multiple of $tileWidth.\n'
        '  → ${remainderX}px remainder on the right edge will be ignored.\n'
        '  → Usable area: ${imageWidth - remainderX}x${imageHeight - remainderY} '
        '($columns columns × $rows rows = ${columns * rows} slots).',
      );
    }

    if (remainderY > 0) {
      warnings.add(
        '[SpriteSheet] WARNING: \'$sheetName\' height ($imageHeight) is not a '
        'multiple of $tileHeight.\n'
        '  → ${remainderY}px remainder on the bottom edge will be ignored.',
      );
    }

    return GridResult(
      info: GridInfo(
        columns: columns,
        rows: rows,
        totalSlots: columns * rows,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        remainderX: remainderX,
        remainderY: remainderY,
      ),
      warnings: warnings,
    );
  }
}

/// Parses spritesheet filenames to extract tile dimensions.
///
/// Convention:
///   {name}_{width}px.{ext}          → square tiles (width × width)
///   {name}_{width}x{height}px.{ext} → non-square tiles (width × height)
///
/// Examples:
///   icons_32px.png          → tileWidth=32, tileHeight=32
///   characters_32x48px.png  → tileWidth=32, tileHeight=48
class NamingConvention {
  static final _regex = RegExp(r'^(.+?)_(\d+)(?:x(\d+))?px$');

  /// Parse a filename [stem] (no extension, no directory path).
  /// Returns null if the convention doesn't match.
  static ParsedConvention? parse(String stem) {
    final match = _regex.firstMatch(stem);
    if (match == null) return null;

    final name = match.group(1)!;
    final width = int.parse(match.group(2)!);
    final height = match.group(3) != null ? int.parse(match.group(3)!) : width;

    return ParsedConvention(name: name, tileWidth: width, tileHeight: height);
  }

  /// Extract the filename stem from a full path (strips directory and extension).
  static String stemFrom(String path) {
    final filename = path.split('/').last.split(r'\').last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex >= 0 ? filename.substring(0, dotIndex) : filename;
  }
}

class ParsedConvention {
  final String name;
  final int tileWidth;
  final int tileHeight;

  const ParsedConvention({
    required this.name,
    required this.tileWidth,
    required this.tileHeight,
  });

  bool get isSquare => tileWidth == tileHeight;

  @override
  String toString() =>
      'ParsedConvention(name: $name, tileWidth: $tileWidth, tileHeight: $tileHeight)';
}

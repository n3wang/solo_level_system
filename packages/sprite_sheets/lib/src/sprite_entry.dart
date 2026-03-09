import 'dart:ui' as ui;

/// A single sprite: its name, grid index, source rectangle, and optional metadata.
class SpriteEntry {
  final String name;
  final int index;
  final ui.Rect sourceRect;
  final Map<String, String> metadata;

  const SpriteEntry({
    required this.name,
    required this.index,
    required this.sourceRect,
    this.metadata = const {},
  });

  /// Convenience: split the semicolon-separated `tags` metadata column.
  List<String> get tags {
    final raw = metadata['tags'] ?? '';
    if (raw.isEmpty) return [];
    return raw.split(';').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  @override
  String toString() =>
      'SpriteEntry(name: $name, index: $index, rect: $sourceRect)';
}

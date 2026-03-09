import 'dart:ui' as ui;

import 'grid_calculator.dart';
import 'sprite_entry.dart';

/// Describes a loaded sheet for external inspection.
class SheetInfo {
  final int columns;
  final int rows;
  final int totalSlots;
  final int namedCount;
  final int tileWidth;
  final int tileHeight;

  const SheetInfo({
    required this.columns,
    required this.rows,
    required this.totalSlots,
    required this.namedCount,
    required this.tileWidth,
    required this.tileHeight,
  });
}

/// A fully-loaded spritesheet: the GPU texture + the manifest of named sprites.
///
/// The texture is never pre-sliced — individual sprites are rendered via
/// [canvas.drawImageRect] using the [sourceRect] in each [SpriteEntry].
class LoadedSheet {
  final ui.Image image;
  final GridInfo grid;
  final List<SpriteEntry> entries;
  final Map<String, SpriteEntry> _byName;
  final Map<int, SpriteEntry> _byIndex;

  LoadedSheet({
    required this.image,
    required this.grid,
    required this.entries,
  })  : _byName = {for (final e in entries) e.name: e},
        _byIndex = {for (final e in entries) e.index: e};

  SheetInfo get info => SheetInfo(
        columns: grid.columns,
        rows: grid.rows,
        totalSlots: grid.totalSlots,
        namedCount: entries.length,
        tileWidth: grid.tileWidth,
        tileHeight: grid.tileHeight,
      );

  /// Look up a sprite by name. Returns null when not found.
  SpriteEntry? entry(String name) => _byName[name];

  /// Look up a sprite by grid index. Returns null when not found.
  SpriteEntry? entryAt(int index) => _byIndex[index];

  /// Compute the source [ui.Rect] for any index, even unnamed slots.
  ui.Rect rectAt(int index) {
    final col = index % grid.columns;
    final row = index ~/ grid.columns;
    return ui.Rect.fromLTWH(
      (col * grid.tileWidth).toDouble(),
      (row * grid.tileHeight).toDouble(),
      grid.tileWidth.toDouble(),
      grid.tileHeight.toDouble(),
    );
  }

  /// Filter entries by a predicate (e.g. by tag or category).
  List<SpriteEntry> where(bool Function(SpriteEntry) predicate) =>
      entries.where(predicate).toList();
}

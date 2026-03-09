import 'package:flutter/material.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

/// Displays a board-game icon from the `motivation_64` spritesheet.
///
/// Sprites are identified by the game name as it appears in the CSV
/// (e.g. `"Codenames"`, `"Pandemic"`).
///
/// ```dart
/// GameIconWidget(name: 'Codenames', size: 64)
/// GameIconWidget(name: 'Pandemic', size: 48, backgroundColor: Colors.black)
/// ```
///
/// Metadata (description, category) is available via [GameIconWidget.entryFor].
class GameIconWidget extends StatelessWidget {
  static const _sheet = 'motivation_64';

  final String name;
  final double? size;
  final Color? backgroundColor;
  final Widget? placeholder;

  const GameIconWidget({
    super.key,
    required this.name,
    this.size,
    this.backgroundColor,
    this.placeholder,
  });

  /// Synchronous access to the sprite entry metadata (description, category).
  /// Returns null if the sheet isn't loaded yet or the name isn't found.
  static SpriteEntry? entryFor(String name) =>
      SpriteSheets.of(_sheet)?.entry(name);

  /// All loaded game entries, optionally filtered by category.
  static List<SpriteEntry> allEntries({String? category}) {
    final sheet = SpriteSheets.of(_sheet);
    if (sheet == null) return [];
    if (category == null) return sheet.entries;
    return sheet.where((e) => e.metadata['category'] == category);
  }

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return RepaintBoundary(
        child: ColoredBox(
          color: backgroundColor ?? Colors.transparent,
          child: SpriteImage(sheet: _sheet, name: name, size: size),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.biggest.shortestSide;
          return ColoredBox(
            color: backgroundColor ?? Colors.transparent,
            child: SpriteImage(sheet: _sheet, name: name, size: s),
          );
        },
      ),
    );
  }
}

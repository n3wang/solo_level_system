import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'missing_sprite_behavior.dart';
import 'sprite_image_painter.dart';
import 'sprite_sheet_registry.dart';

/// Displays a single sprite from a named spritesheet.
///
/// The sheet must have been loaded via [SpriteSheets.init] before this widget
/// is built.  When the sheet is already in cache the sprite renders in the
/// first frame with no loading flash.
///
/// ```dart
/// // By name (requires CSV manifest)
/// SpriteImage(sheet: 'icons_32px', name: 'sword')
///
/// // By grid index (no CSV required)
/// SpriteImage(sheet: 'icons_32px', index: 5)
///
/// // Custom display size
/// SpriteImage(sheet: 'icons_32px', name: 'sword', size: 48)
/// SpriteImage(sheet: 'icons_32px', name: 'sword', width: 64, height: 32)
/// ```
class SpriteImage extends StatelessWidget {
  final String sheet;
  final String? name;
  final int? index;
  final double? size;
  final double? width;
  final double? height;

  const SpriteImage({
    super.key,
    required this.sheet,
    this.name,
    this.index,
    this.size,
    this.width,
    this.height,
  }) : assert(
          name != null || index != null,
          'SpriteImage requires either name or index.',
        );

  @override
  Widget build(BuildContext context) {
    final w = (width ?? size)?.toDouble();
    final h = (height ?? size)?.toDouble();
    final effectiveW = w ?? 64.0;
    final effectiveH = h ?? 64.0;

    return FutureBuilder<_SpriteData?>(
      // SynchronousFuture when already cached → renders in first frame
      future: _resolve(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: effectiveW, height: effectiveH);
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _missing(effectiveW, effectiveH);
        }

        final data = snapshot.data!;
        return CustomPaint(
          size: Size(effectiveW, effectiveH),
          painter: SpriteImagePainter(
            sheet: data.image,
            sourceRect: data.sourceRect,
          ),
        );
      },
    );
  }

  /// Returns a [SynchronousFuture] when the sheet is already in cache,
  /// so [FutureBuilder] sees [ConnectionState.done] on the first frame.
  Future<_SpriteData?> _resolve() {
    // Fast path: sheet already loaded
    final cached = SpriteSheets.of(sheet);
    if (cached != null) {
      return SynchronousFuture(_extract(cached));
    }
    // Slow path: wait for load (sheet not yet in cache)
    return SpriteSheets.instance.getSheet(sheet).then(
          (loaded) => loaded != null ? _extract(loaded) : null,
        );
  }

  _SpriteData? _extract(loaded) {
    ui.Rect? rect;

    if (name != null) {
      final entry = loaded.entry(name!);
      if (entry == null) {
        _warnMissing(loaded);
        return null;
      }
      rect = entry.sourceRect;
    } else if (index != null) {
      if (index! < 0 || index! >= loaded.grid.totalSlots) return null;
      rect = loaded.rectAt(index!);
    }

    if (rect == null) return null;
    return _SpriteData(image: loaded.image, sourceRect: rect);
  }

  void _warnMissing(loaded) {
    final behavior = SpriteSheets.instance.missingBehavior;
    final suggestion = SpriteSheets.suggest(
      name!,
      (loaded.entries as List).map((e) => e.name as String),
    );
    assert(() {
      final hint = suggestion != null
          ? '  → Did you mean: \'$suggestion\'?'
          : '  → No close match found.';
      // ignore: avoid_print
      print('[SpriteSheet] WARNING: Sprite \'$name\' not found in \'$sheet\'.\n$hint');
      return true;
    }());
    if (behavior == MissingSpriteBehavior.error) {
      throw StateError('[SpriteSheet] Sprite \'$name\' not found in \'$sheet\'.');
    }
  }

  Widget _missing(double w, double h) {
    final behavior = SpriteSheets.instance.missingBehavior;
    if (behavior == MissingSpriteBehavior.transparent) {
      return SizedBox(width: w, height: h);
    }
    return Container(
      width: w,
      height: h,
      color: const Color(0xFFFF00FF),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _SpriteData {
  final ui.Image image;
  final ui.Rect sourceRect;
  const _SpriteData({required this.image, required this.sourceRect});
}

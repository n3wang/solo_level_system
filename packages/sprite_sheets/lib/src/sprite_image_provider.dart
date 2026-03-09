import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sprite_sheet_registry.dart';

/// An [ImageProvider] that blits a named sprite from a loaded sheet.
///
/// Use for [BoxDecoration], [CircleAvatar], or any API that accepts
/// [ImageProvider]:
///
/// ```dart
/// final provider = SpriteSheets.providerFor(sheet: 'icons_32px', name: 'sword');
/// Image(image: provider)
/// DecorationImage(image: provider)
/// ```
class SpriteImageProvider extends ImageProvider<SpriteImageProvider> {
  final String sheet;
  final String name;

  const SpriteImageProvider({required this.sheet, required this.name});

  @override
  Future<SpriteImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    SpriteImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _blit(),
      scale: 1.0,
      debugLabel: 'SpriteImage($sheet/$name)',
    );
  }

  Future<ui.Codec> _blit() async {
    final loaded = await SpriteSheets.instance.getSheet(sheet);
    if (loaded == null) {
      throw StateError('[SpriteSheet] Sheet \'$sheet\' not loaded.');
    }

    final entry = loaded.entry(name);
    if (entry == null) {
      throw StateError(
          '[SpriteSheet] Sprite \'$name\' not found in \'$sheet\'.');
    }

    // Blit the sprite to a temporary image so the provider returns a correct size.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      loaded.image,
      entry.sourceRect,
      ui.Rect.fromLTWH(
          0, 0, entry.sourceRect.width, entry.sourceRect.height),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      entry.sourceRect.width.round(),
      entry.sourceRect.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return ui.instantiateImageCodec(bytes!.buffer.asUint8List());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpriteImageProvider &&
          runtimeType == other.runtimeType &&
          sheet == other.sheet &&
          name == other.name;

  @override
  int get hashCode => Object.hash(sheet, name);
}

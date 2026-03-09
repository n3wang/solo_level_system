import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// [CustomPainter] that blits a rectangular region from a spritesheet texture.
///
/// Uses a single [canvas.drawImageRect] call — zero allocation, one GPU blit.
class SpriteImagePainter extends CustomPainter {
  final ui.Image sheet;
  final ui.Rect sourceRect;

  const SpriteImagePainter({
    required this.sheet,
    required this.sourceRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      sheet,
      sourceRect,
      Offset.zero & size,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(SpriteImagePainter old) =>
      old.sheet != sheet || old.sourceRect != sourceRect;
}

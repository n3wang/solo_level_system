import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../sprite_sheet_registry.dart';

/// A full-grid debug view of a spritesheet.
///
/// Renders every slot with its name (or index) overlaid. Use during
/// development to verify that names, indices, and tile sizes are correct.
///
/// ```dart
/// SpriteSheetDebugOverlay(sheet: 'icons_32px', tileDisplaySize: 64)
/// ```
class SpriteSheetDebugOverlay extends StatelessWidget {
  final String sheet;

  /// The pixel size at which each tile is displayed on screen.
  final double tileDisplaySize;

  const SpriteSheetDebugOverlay({
    super.key,
    required this.sheet,
    this.tileDisplaySize = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SpriteSheets.instance.getSheet(sheet),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text('[SpriteSheet] Sheet \'$sheet\' not found.'),
          );
        }

        final loaded = snapshot.data!;
        final info = loaded.info;
        final aspect = info.tileWidth / info.tileHeight;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: info.columns,
            childAspectRatio: aspect,
          ),
          itemCount: info.totalSlots,
          itemBuilder: (context, i) {
            final entry = loaded.entryAt(i);
            final rect = loaded.rectAt(i);
            final label = entry?.name ?? '$i';

            return Stack(
              children: [
                CustomPaint(
                  size: Size(tileDisplaySize, tileDisplaySize / aspect),
                  painter: _TilePainter(image: loaded.image, sourceRect: rect),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                    color: const Color(0xAA000000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: const SizedBox.expand(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TilePainter extends CustomPainter {
  final ui.Image image;
  final ui.Rect sourceRect;

  const _TilePainter({required this.image, required this.sourceRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(image, sourceRect, Offset.zero & size, Paint());
  }

  @override
  bool shouldRepaint(_TilePainter old) => false;
}

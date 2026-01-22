// lib/utils/workout_sprite_slicer.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Utility class for loading pre-sliced workout icon images
/// Sprites are pre-sliced at build time using scripts/slice_workout_sprites.dart
/// Icons are stored with slug names (e.g., back_squat.png, jumping_jacks.png)
class WorkoutSpriteSlicer {
  static const int spriteSize = 128;
  static const String spriteSheetPath = 'assets/icon/workout_icons_128px.png';
  static const String slicedSpriteDir = 'assets/icon/workout_icons_sliced';

  // Cache for loaded sprites by slug name
  static final Map<String, ui.Image> _slugCache = {};

  // Legacy cache for index-based loading
  static final Map<int, ui.Image> _spriteCache = {};

  /// Get a sprite by slug name (e.g., "back_squat", "jumping_jacks")
  /// Loads from assets/icon/workout_icons_sliced/{slug}.png
  static Future<ui.Image?> getSpriteBySlug(String slug) async {
    // Return cached sprite if available
    if (_slugCache.containsKey(slug)) {
      return _slugCache[slug];
    }

    try {
      final String path = '$slicedSpriteDir/$slug.png';

      final ByteData data = await rootBundle.load(path);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image spriteImage = frameInfo.image;

      // Cache the sprite for future use
      _slugCache[slug] = spriteImage;
      return spriteImage;
    } catch (e) {
      print('Error loading sprite "$slug": $e');

      // Try legacy fallback if slug looks like workout_icon_INDEX
      if (slug.startsWith('workout_icon_')) {
        final indexStr = slug.replaceFirst('workout_icon_', '');
        final index = int.tryParse(indexStr);
        if (index != null) {
          return await getSpriteAtIndex(index);
        }
      }

      return null;
    }
  }

  /// Get a specific sprite from pre-sliced images by index (legacy support)
  /// Index 0 = first icon, Index 1 = second icon, etc.
  /// Uses caching to prevent reloading
  /// Falls back to runtime slicing if pre-sliced image not found
  static Future<ui.Image?> getSpriteAtIndex(int index) async {
    // Return cached sprite if available
    if (_spriteCache.containsKey(index)) {
      return _spriteCache[index];
    }

    try {
      // Try to load pre-sliced image by index (legacy format)
      final String slicedPath = '$slicedSpriteDir/workout_icon_$index.png';

      try {
        final ByteData data = await rootBundle.load(slicedPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image spriteImage = frameInfo.image;

        // Cache the sprite for future use
        _spriteCache[index] = spriteImage;
        return spriteImage;
      } catch (e) {
        // Pre-sliced image not found, fall back to runtime slicing
        print(
          'Pre-sliced image not found for index $index, falling back to runtime slicing',
        );
        return await _getSpriteAtIndexRuntime(index);
      }
    } catch (e) {
      print('Error loading sprite at index $index: $e');
      return null;
    }
  }

  /// Fallback: Get sprite by runtime slicing (for backward compatibility)
  /// This should only be used if pre-sliced images are not available
  static Future<ui.Image?> _getSpriteAtIndexRuntime(int index) async {
    try {
      // Load sprite sheet
      final ByteData data = await rootBundle.load(spriteSheetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image fullImage = frameInfo.image;

      // Calculate the x position of the sprite
      final int x = index * spriteSize;

      // Create a new image with just this sprite
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      canvas.drawImageRect(
        fullImage,
        Rect.fromLTWH(
          x.toDouble(),
          0,
          spriteSize.toDouble(),
          spriteSize.toDouble(),
        ),
        Rect.fromLTWH(0, 0, spriteSize.toDouble(), spriteSize.toDouble()),
        Paint(),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image spriteImage = await picture.toImage(
        spriteSize,
        spriteSize,
      );

      // Cache the sprite for future use
      _spriteCache[index] = spriteImage;

      return spriteImage;
    } catch (e) {
      print('Error runtime slicing sprite at index $index: $e');
      return null;
    }
  }

  /// Get a widget that displays a specific sprite by slug
  static Widget getSpriteWidgetBySlug(
    String slug, {
    double? size,
    Color? backgroundColor,
  }) {
    final bgColor = backgroundColor ?? Colors.white;

    return FutureBuilder<ui.Image?>(
      key: ValueKey('sprite_$slug'),
      future: getSpriteBySlug(slug),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: size ?? spriteSize.toDouble(),
            height: size ?? spriteSize.toDouble(),
            color: bgColor,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            width: size ?? spriteSize.toDouble(),
            height: size ?? spriteSize.toDouble(),
            color: bgColor,
            child: Icon(
              Icons.fitness_center,
              size: size ?? spriteSize.toDouble(),
            ),
          );
        }

        return Container(
          width: size ?? spriteSize.toDouble(),
          height: size ?? spriteSize.toDouble(),
          color: bgColor,
          child: CustomPaint(
            size: Size(
              size ?? spriteSize.toDouble(),
              size ?? spriteSize.toDouble(),
            ),
            painter: SpritePainter(snapshot.data!),
          ),
        );
      },
    );
  }

  /// Get a widget that displays a specific sprite by index (legacy support)
  static Widget getSpriteWidget(
    int index, {
    double? size,
    Color? backgroundColor,
  }) {
    final bgColor = backgroundColor ?? Colors.white;

    return FutureBuilder<ui.Image?>(
      key: ValueKey('sprite_$index'),
      future: getSpriteAtIndex(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: size ?? spriteSize.toDouble(),
            height: size ?? spriteSize.toDouble(),
            color: bgColor,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            width: size ?? spriteSize.toDouble(),
            height: size ?? spriteSize.toDouble(),
            color: bgColor,
            child: Icon(
              Icons.fitness_center,
              size: size ?? spriteSize.toDouble(),
            ),
          );
        }

        return Container(
          width: size ?? spriteSize.toDouble(),
          height: size ?? spriteSize.toDouble(),
          color: bgColor,
          child: CustomPaint(
            size: Size(
              size ?? spriteSize.toDouble(),
              size ?? spriteSize.toDouble(),
            ),
            painter: SpritePainter(snapshot.data!),
          ),
        );
      },
    );
  }

  /// Get the sprite sheet image for direct use
  static Future<ui.Image?> getSpriteSheet() async {
    try {
      final ByteData data = await rootBundle.load(spriteSheetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    } catch (e) {
      print('Error loading sprite sheet: $e');
      return null;
    }
  }

  /// Get the number of sprites available
  static Future<int> getSpriteCount() async {
    try {
      // Count from sprite sheet width
      final ui.Image? image = await getSpriteSheet();
      if (image == null) return 0;
      return (image.width / spriteSize).floor();
    } catch (e) {
      print('Error getting sprite count: $e');
      return 0;
    }
  }

  /// Clear all cached sprites (useful for memory management)
  static void clearCache() {
    _slugCache.clear();
    _spriteCache.clear();
  }

  /// Get sprite as ImageProvider for use in Image widgets (legacy support)
  static ImageProvider getSpriteImageProvider(int index) {
    return WorkoutSpriteImageProvider(index);
  }
}

/// Custom painter for drawing sprites
class SpritePainter extends CustomPainter {
  final ui.Image image;

  SpritePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(SpritePainter oldDelegate) => false;
}

/// Custom ImageProvider for workout sprites (legacy support)
class WorkoutSpriteImageProvider
    extends ImageProvider<WorkoutSpriteImageProvider> {
  final int index;

  WorkoutSpriteImageProvider(this.index);

  @override
  Future<WorkoutSpriteImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    WorkoutSpriteImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(codec: _loadAsync(key), scale: 1.0);
  }

  Future<ui.Codec> _loadAsync(WorkoutSpriteImageProvider key) async {
    final sprite = await WorkoutSpriteSlicer.getSpriteAtIndex(key.index);
    if (sprite == null) {
      throw Exception('Failed to load sprite at index ${key.index}');
    }

    final ByteData? data = await sprite.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (data == null) {
      throw Exception('Failed to convert sprite to bytes');
    }

    return await ui.instantiateImageCodec(data.buffer.asUint8List());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSpriteImageProvider &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}

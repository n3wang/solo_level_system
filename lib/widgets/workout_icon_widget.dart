// lib/widgets/workout_icon_widget.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/workout_sprite_slicer.dart';

/// Widget to display workout icons from the sprite sheet
/// Extracts the sprite index from exercise.imageUrl (format: 'workout_sprite_INDEX')
/// Uses StatefulWidget to cache the loaded image and prevent reloading
class WorkoutIconWidget extends StatefulWidget {
  final String? imageUrl; // Format: 'workout_sprite_INDEX' or null
  final double? size;
  final Widget? placeholder;
  final Color? backgroundColor; // Background color for the sprite

  const WorkoutIconWidget({
    super.key,
    this.imageUrl,
    this.size,
    this.placeholder,
    this.backgroundColor,
  });

  @override
  State<WorkoutIconWidget> createState() => _WorkoutIconWidgetState();
}

class _WorkoutIconWidgetState extends State<WorkoutIconWidget> {
  ui.Image? _cachedImage;
  bool _isLoading = true;
  int? _currentSpriteIndex;

  /// Extract sprite index from imageUrl
  int? _getSpriteIndex() {
    if (widget.imageUrl == null) return null;
    if (widget.imageUrl!.startsWith('workout_sprite_')) {
      final indexStr = widget.imageUrl!.replaceFirst('workout_sprite_', '');
      return int.tryParse(indexStr);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentSpriteIndex = _getSpriteIndex();
    _loadImage();
  }

  @override
  void didUpdateWidget(WorkoutIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if imageUrl actually changed
    final newSpriteIndex = _getSpriteIndex();
    if (_currentSpriteIndex != newSpriteIndex) {
      _currentSpriteIndex = newSpriteIndex;
      _cachedImage = null;
      _isLoading = true;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final spriteIndex = _currentSpriteIndex;
    if (spriteIndex == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Load image (will use cache internally)
    final image = await WorkoutSpriteSlicer.getSpriteAtIndex(spriteIndex);
    if (mounted && _currentSpriteIndex == spriteIndex) {
      setState(() {
        _cachedImage = image;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spriteIndex = _getSpriteIndex();
    final bgColor = widget.backgroundColor ?? Colors.white;
    
    if (spriteIndex == null) {
      if (widget.size != null) {
        return widget.placeholder ?? 
               SizedBox(
                 width: widget.size,
                 height: widget.size,
                 child: Icon(Icons.fitness_center, size: widget.size),
               );
      } else {
        return widget.placeholder ??
               LayoutBuilder(
                 builder: (context, constraints) {
                   final size = constraints.biggest.shortestSide;
                   return SizedBox(
                     width: size,
                     height: size,
                     child: Icon(Icons.fitness_center, size: size * 0.6),
                   );
                 },
               );
      }
    }

    if (_isLoading || _cachedImage == null) {
      if (widget.size != null) {
        return widget.placeholder ??
            Container(
              width: widget.size,
              height: widget.size,
              color: bgColor,
              child: _isLoading 
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.fitness_center, size: widget.size! * 0.6),
            );
      } else {
        return widget.placeholder ??
               LayoutBuilder(
                 builder: (context, constraints) {
                   final size = constraints.biggest.shortestSide;
                   return Container(
                     width: size,
                     height: size,
                     color: bgColor,
                     child: _isLoading 
                         ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                         : Icon(Icons.fitness_center, size: size * 0.6),
                   );
                 },
               );
      }
    }

    // Once image is loaded, use RepaintBoundary to prevent unnecessary repaints
    if (widget.size != null) {
      return RepaintBoundary(
        child: Container(
          width: widget.size,
          height: widget.size,
          color: bgColor,
          child: CustomPaint(
            size: Size(widget.size!, widget.size!),
            painter: _SpritePainter(_cachedImage!, fit: BoxFit.contain),
          ),
        ),
      );
    } else {
      return RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide;
            return Container(
              width: size,
              height: size,
              color: bgColor,
              child: CustomPaint(
                size: Size(size, size),
                painter: _SpritePainter(_cachedImage!, fit: BoxFit.contain),
              ),
            );
          },
        ),
      );
    }
  }
}

/// Custom painter for drawing cached sprites
class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  _SpritePainter(this.image, {this.fit = BoxFit.contain});

  @override
  void paint(Canvas canvas, Size size) {
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final dstSize = size;
    
    Rect srcRect, dstRect;
    
    if (fit == BoxFit.contain) {
      // Calculate aspect ratios
      final srcAspect = srcSize.width / srcSize.height;
      final dstAspect = dstSize.width / dstSize.height;
      
      if (srcAspect > dstAspect) {
        // Image is wider - fit to width
        final scaledHeight = dstSize.width / srcAspect;
        dstRect = Rect.fromLTWH(
          0,
          (dstSize.height - scaledHeight) / 2,
          dstSize.width,
          scaledHeight,
        );
      } else {
        // Image is taller - fit to height
        final scaledWidth = dstSize.height * srcAspect;
        dstRect = Rect.fromLTWH(
          (dstSize.width - scaledWidth) / 2,
          0,
          scaledWidth,
          dstSize.height,
        );
      }
      srcRect = Rect.fromLTWH(0, 0, srcSize.width, srcSize.height);
    } else {
      // Default: fill (for backward compatibility)
      srcRect = Rect.fromLTWH(0, 0, srcSize.width, srcSize.height);
      dstRect = Rect.fromLTWH(0, 0, dstSize.width, dstSize.height);
    }
    
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) => 
      oldDelegate.image != image || oldDelegate.fit != fit;
}

/// Widget to display workout icon from sprite index directly
class WorkoutIconByIndexWidget extends StatelessWidget {
  final int spriteIndex;
  final double? size;
  final Color? backgroundColor;

  const WorkoutIconByIndexWidget({
    super.key,
    required this.spriteIndex,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return WorkoutSpriteSlicer.getSpriteWidget(
      spriteIndex,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white, // Default white background
    );
  }
}

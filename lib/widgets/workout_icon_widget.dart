// lib/widgets/workout_icon_widget.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/workout_sprite_slicer.dart';

/// Widget to display workout icons by slug name
/// Uses the imageUrl field directly as the icon slug (e.g., "back_squat", "jumping_jacks")
/// Loads from assets/icon/workout_icons_sliced/{slug}.png
class WorkoutIconWidget extends StatefulWidget {
  final String? imageUrl; // Icon slug (e.g., "back_squat", "jumping_jacks")
  final double? size;
  final Widget? placeholder;
  final Color? backgroundColor;

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
  String? _currentSlug;

  /// Get the icon slug from imageUrl
  /// Handles both new format (slug) and legacy format (workout_sprite_INDEX)
  String? _getIconSlug() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return null;

    // Handle legacy format: workout_sprite_INDEX
    if (widget.imageUrl!.startsWith('workout_sprite_')) {
      // Convert to index-based filename for backward compatibility
      final indexStr = widget.imageUrl!.replaceFirst('workout_sprite_', '');
      final index = int.tryParse(indexStr);
      if (index != null) {
        return 'workout_icon_$index'; // Legacy fallback
      }
    }

    // New format: use imageUrl directly as slug
    return widget.imageUrl;
  }

  @override
  void initState() {
    super.initState();
    _currentSlug = _getIconSlug();
    _loadImage();
  }

  @override
  void didUpdateWidget(WorkoutIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSlug = _getIconSlug();
    if (_currentSlug != newSlug) {
      _currentSlug = newSlug;
      _cachedImage = null;
      _isLoading = true;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final slug = _currentSlug;
    if (slug == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Load image by slug name
    final image = await WorkoutSpriteSlicer.getSpriteBySlug(slug);
    if (mounted && _currentSlug == slug) {
      setState(() {
        _cachedImage = image;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = _getIconSlug();
    final bgColor = widget.backgroundColor ?? Colors.white;

    if (slug == null) {
      return _buildPlaceholder(bgColor);
    }

    if (_isLoading || _cachedImage == null) {
      return _buildLoading(bgColor);
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

  Widget _buildPlaceholder(Color bgColor) {
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

  Widget _buildLoading(Color bgColor) {
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
      final srcAspect = srcSize.width / srcSize.height;
      final dstAspect = dstSize.width / dstSize.height;

      if (srcAspect > dstAspect) {
        final scaledHeight = dstSize.width / srcAspect;
        dstRect = Rect.fromLTWH(
          0,
          (dstSize.height - scaledHeight) / 2,
          dstSize.width,
          scaledHeight,
        );
      } else {
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

/// Widget to display workout icon by slug name directly
class WorkoutIconBySlugWidget extends StatelessWidget {
  final String slug;
  final double? size;
  final Color? backgroundColor;

  const WorkoutIconBySlugWidget({
    super.key,
    required this.slug,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return WorkoutIconWidget(
      imageUrl: slug,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
    );
  }
}

/// Legacy widget - kept for backward compatibility
/// @deprecated Use WorkoutIconBySlugWidget instead
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
    return WorkoutIconWidget(
      imageUrl: 'workout_icon_$spriteIndex',
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
    );
  }
}

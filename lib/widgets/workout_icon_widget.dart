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
    final size = widget.size ?? 128.0;
    
    if (spriteIndex == null) {
      return widget.placeholder ?? 
             SizedBox(
               width: size,
               height: size,
               child: Icon(Icons.fitness_center, size: size),
             );
    }

    if (_isLoading || _cachedImage == null) {
      return widget.placeholder ??
          Container(
            width: size,
            height: size,
            color: bgColor,
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.fitness_center, size: size),
          );
    }

    // Once image is loaded, use RepaintBoundary to prevent unnecessary repaints
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        color: bgColor,
        child: CustomPaint(
          size: Size(size, size),
          painter: _SpritePainter(_cachedImage!),
        ),
      ),
    );
  }
}

/// Custom painter for drawing cached sprites
class _SpritePainter extends CustomPainter {
  final ui.Image image;

  _SpritePainter(this.image);

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
  bool shouldRepaint(_SpritePainter oldDelegate) => false;
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

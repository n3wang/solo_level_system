// lib/widgets/workout_icon_widget.dart
import 'package:flutter/material.dart';
import '../utils/workout_sprite_slicer.dart';

/// Widget to display workout icons from the sprite sheet
/// Extracts the sprite index from exercise.imageUrl (format: 'workout_sprite_INDEX')
class WorkoutIconWidget extends StatelessWidget {
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

  /// Extract sprite index from imageUrl
  int? _getSpriteIndex() {
    if (imageUrl == null) return null;
    if (imageUrl!.startsWith('workout_sprite_')) {
      final indexStr = imageUrl!.replaceFirst('workout_sprite_', '');
      return int.tryParse(indexStr);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spriteIndex = _getSpriteIndex();
    
    if (spriteIndex == null) {
      return placeholder ?? 
             SizedBox(
               width: size ?? 128,
               height: size ?? 128,
               child: Icon(Icons.fitness_center, size: size ?? 128),
             );
    }

    return WorkoutSpriteSlicer.getSpriteWidget(
      spriteIndex,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white, // Default white background
    );
  }
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

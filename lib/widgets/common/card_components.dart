// lib/widgets/common/card_components.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// A reusable card component with consistent styling and layout
class BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const BaseCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: padding ?? EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// A header component for cards with icon, title, and description
class CardHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Color color;
  final IconData? icon;
  final String? iconName;
  final Widget? trailing;

  const CardHeader({
    super.key,
    required this.title,
    this.description,
    required this.color,
    this.icon,
    this.iconName,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildIcon(),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (description?.isNotEmpty == true) ...[
                SizedBox(height: 4),
                Text(
                  description!,
                  style: TextStyle(color: AppColorPalette.grey600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }

  Widget _buildIcon() {
    if (icon != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      );
    } else if (iconName != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getIconData(iconName!), color: color, size: 20),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title[0].toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'music_note':
        return Icons.music_note;
      case 'home':
        return Icons.home;
      case 'business':
        return Icons.business;
      case 'psychology':
        return Icons.psychology;
      case 'science':
        return Icons.science;
      case 'book':
        return Icons.book;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.folder;
    }
  }
}

/// A stats chip component for displaying key-value pairs
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? AppColorPalette.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColorPalette.grey600),
          SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(fontSize: 12, color: color ?? AppColorPalette.grey700),
          ),
        ],
      ),
    );
  }
}

/// A priority chip component
class PriorityChip extends StatelessWidget {
  final int priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor(priority);
    final text = _getPriorityText(priority);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return AppColorPalette.priorityHigh; // Green
      case 2:
        return AppColorPalette.priorityMedium; // Orange
      case 3:
        return AppColorPalette.priorityUrgent; // Red
      case 4:
        return AppColorPalette.priorityLow; // Purple
      default:
        return AppColorPalette.grey;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Urgent';
      default:
        return 'None';
    }
  }
}

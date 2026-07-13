import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

enum SettingsRectChipSize { compact, regular }

/// One option in a [SettingsRectChipGroup].
class SettingsRectChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SettingsRectChipOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Exclusive radio-style row of [SettingsRectChip]s.
/// Optional [title] (omit for Motivation filters). Use [size] for compact filters.
class SettingsRectChipGroup<T> extends StatelessWidget {
  final String? title;
  final List<SettingsRectChipOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final SettingsRectChipSize size;
  final Color? activeColor;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleStyle;
  final WrapAlignment alignment;

  const SettingsRectChipGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.title,
    this.size = SettingsRectChipSize.regular,
    this.activeColor,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding,
    this.titlePadding,
    this.titleStyle,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: options.map((option) {
        return SettingsRectChip(
          label: option.label,
          icon: option.icon,
          selected: option.value == value,
          size: size,
          activeColor: activeColor,
          onTap: () => onChanged(option.value),
        );
      }).toList(),
    );

    if (title == null) {
      return padding == null ? chips : Padding(padding: padding!, child: chips);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: titlePadding ??
              const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            title!,
            style: titleStyle ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColorPalette.textSecondary,
                ),
          ),
        ),
        Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          child: chips,
        ),
      ],
    );
  }
}

/// Shared rectangular chip used by On/Off toggles, presets, and filters.
/// Uses [AppUiSizes.buttonRadius] — slightly rounded, not pill-shaped.
class SettingsRectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;
  final IconData? icon;
  final double? iconSize;
  final SettingsRectChipSize size;

  const SettingsRectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.activeColor,
    this.icon,
    this.iconSize,
    this.size = SettingsRectChipSize.regular,
  });

  bool get _compact => size == SettingsRectChipSize.compact;

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;
    final foreground =
        selected ? AppColorPalette.white : AppColorPalette.grey800;
    final resolvedIconSize = iconSize ?? (_compact ? 14.0 : 16.0);
    final fontSize = _compact ? 11.0 : 13.0;
    final horizontal = _compact ? 8.0 : 14.0;
    final vertical = _compact ? 4.0 : 6.0;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
              border: Border.all(
                color: selected ? accent : AppColorPalette.grey800,
                width: _compact ? 1.2 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: resolvedIconSize, color: foreground),
                  if (label.isNotEmpty) const SizedBox(width: 6),
                ],
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

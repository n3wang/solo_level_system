import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Compact rectangle toggle. Defaults to "On" / "Off"; optional custom
/// labels and icons for each state.
class OnOffToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final String onLabel;
  final String offLabel;
  final IconData? onIcon;
  final IconData? offIcon;
  final double iconSize;

  const OnOffToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.onLabel = 'On',
    this.offLabel = 'Off',
    this.onIcon,
    this.offIcon,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRectChip(
      label: value ? onLabel : offLabel,
      icon: value ? onIcon : offIcon,
      iconSize: iconSize,
      selected: value,
      activeColor: activeColor,
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

/// Settings-style list row with [OnOffToggle] trailing control.
class OnOffToggleListTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final Color? activeColor;
  final String onLabel;
  final String offLabel;
  final IconData? onIcon;
  final IconData? offIcon;

  const OnOffToggleListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.contentPadding,
    this.activeColor,
    this.onLabel = 'On',
    this.offLabel = 'Off',
    this.onIcon,
    this.offIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      trailing: OnOffToggle(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        onLabel: onLabel,
        offLabel: offLabel,
        onIcon: onIcon,
        offIcon: offIcon,
      ),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

/// Shared rectangular chip used by On/Off toggles and settings presets.
/// Uses [AppUiSizes.buttonRadius] — slightly rounded, not pill-shaped.
class SettingsRectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;
  final IconData? icon;
  final double iconSize;

  const SettingsRectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.activeColor,
    this.icon,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;
    final foreground =
        selected ? AppColorPalette.white : AppColorPalette.grey700;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
              border: Border.all(
                color: selected ? accent : AppColorPalette.grey400,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: iconSize, color: foreground),
                  if (label.isNotEmpty) const SizedBox(width: 6),
                ],
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
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

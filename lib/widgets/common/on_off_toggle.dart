import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Compact rectangle toggle showing "On" / "Off".
class OnOffToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const OnOffToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRectChip(
      label: value ? 'On' : 'Off',
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

  const OnOffToggleListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.contentPadding,
    this.activeColor,
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

  const SettingsRectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;

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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? AppColorPalette.white : AppColorPalette.grey700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

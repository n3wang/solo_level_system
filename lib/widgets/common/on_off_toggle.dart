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
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;
    final enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: value ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
              border: Border.all(
                color: value ? accent : AppColorPalette.grey400,
                width: 1.5,
              ),
            ),
            child: Text(
              value ? 'On' : 'Off',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? AppColorPalette.white : AppColorPalette.grey700,
              ),
            ),
          ),
        ),
      ),
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

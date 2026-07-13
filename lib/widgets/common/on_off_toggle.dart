import 'package:flutter/material.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';

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
  final SettingsRectChipSize size;

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
    this.size = SettingsRectChipSize.regular,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRectChip(
      label: value ? onLabel : offLabel,
      icon: value ? onIcon : offIcon,
      iconSize: iconSize,
      selected: value,
      activeColor: activeColor,
      size: size,
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

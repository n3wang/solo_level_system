import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';

/// Shared outlined key used by answer pads and the solution calculator.
class CaseMathKeypadButton extends StatelessWidget {
  const CaseMathKeypadButton({
    super.key,
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onPressed,
    this.compact = false,
    this.opaque = false,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onPressed;
  final bool compact;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: opaque ? surface : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              compact ? AppUiSizes.buttonRadius : AppUiSizes.radiusMd,
            ),
          ),
        ),
        child: icon == null
            ? Text(
                label!,
                style: TextStyle(
                  fontSize: compact ? 14 : 20,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Icon(icon, size: compact ? 15 : 22),
      ),
    );
  }
}

/// Digit grid: 0–9, decimal, backspace. Optional bottom action (e.g. Check).
class CaseMathDigitPad extends StatelessWidget {
  const CaseMathDigitPad({
    super.key,
    required this.onKeyTap,
    required this.onBackspace,
    this.onAction,
    this.actionLabel,
    this.actionIcon = Icons.check,
    this.compact = false,
    this.opaqueKeys = false,
  });

  final ValueChanged<String> onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData actionIcon;
  final bool compact;
  final bool opaqueKeys;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: compact ? 1.55 : 1.7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: compact ? 4 : 8,
          crossAxisSpacing: compact ? 4 : 8,
          children: [
            for (final key in keys)
              CaseMathKeypadButton(
                label: key,
                compact: compact,
                opaque: opaqueKeys,
                onPressed: () => onKeyTap(key),
              ),
            CaseMathKeypadButton(
              icon: Icons.backspace_outlined,
              semanticLabel: 'Backspace',
              compact: compact,
              opaque: opaqueKeys,
              onPressed: onBackspace,
            ),
          ],
        ),
        if (onAction != null && actionLabel != null) ...[
          SizedBox(height: compact ? 6 : AppUiSizes.sm),
          SizedBox(
            width: double.infinity,
            child: PrimaryActionButton(
              text: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ),
        ],
      ],
    );
  }
}

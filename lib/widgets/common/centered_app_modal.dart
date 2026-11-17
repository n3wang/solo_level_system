// lib/widgets/common/centered_app_modal.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';

/// Centered dialog shell with inset margins so the dimmed backdrop
/// remains tappable on all sides.
///
/// Height always fits the space left after [MediaQuery] view insets
/// (keyboard) and [insetPadding], so text fields inside cannot overflow
/// when the keyboard opens.
Future<T?> showCenteredAppModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,

  /// Use [Colors.transparent] when stacking on another modal to avoid
  /// a double-dimmed backdrop.
  Color? barrierColor,
  double horizontalInsetFraction = 0.06,
  double verticalInsetFraction = 0.055,
  double heightFraction = 0.88,
  double borderRadius = AppUiSizes.modalRadius,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final keyboard = media.viewInsets.bottom;
      final horizontalInset = media.size.width * horizontalInsetFraction;
      // Collapse vertical margin when the keyboard is open so the sheet
      // keeps usable height for its content.
      final verticalInset = keyboard > 0
          ? math.min(media.size.height * verticalInsetFraction, 8.0)
          : media.size.height * verticalInsetFraction;
      final maxWidth = media.size.width - horizontalInset * 2;
      // Dialog pads with viewInsets + insetPadding; size the child to that.
      final availableHeight =
          media.size.height - keyboard - verticalInset * 2;
      final maxHeight = math.min(
        media.size.height * heightFraction,
        math.max(availableHeight, 0.0),
      );

      return Dialog(
        insetPadding: EdgeInsets.fromLTRB(
          horizontalInset,
          verticalInset,
          horizontalInset,
          verticalInset,
        ),
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? math.min(maxWidth, constraints.maxWidth)
                : maxWidth;
            final height = constraints.maxHeight.isFinite
                ? math.min(maxHeight, constraints.maxHeight)
                : maxHeight;
            return SizedBox(
              width: width,
              height: height,
              child: builder(context),
            );
          },
        ),
      );
    },
  );
}

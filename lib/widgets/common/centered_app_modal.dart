// lib/widgets/common/centered_app_modal.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';

/// Centered dialog shell with inset margins so the dimmed backdrop
/// remains tappable on all sides.
Future<T?> showCenteredAppModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double horizontalInsetFraction = 0.06,
  double verticalInsetFraction = 0.055,
  double heightFraction = 0.88,
  double borderRadius = AppUiSizes.modalRadius,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxWidth = media.size.width * (1 - horizontalInsetFraction * 2);
      final maxHeight = media.size.height * heightFraction;

      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: media.size.width * horizontalInsetFraction,
          vertical: media.size.height * verticalInsetFraction,
        ),
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: builder(ctx),
        ),
      );
    },
  );
}

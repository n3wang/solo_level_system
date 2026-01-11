// lib/widgets/common/dialog_components.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// A reusable form dialog component
class FormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool scrollable;

  const FormDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: scrollable ? SingleChildScrollView(child: content) : content,
      actions: actions,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

/// A reusable confirmation dialog
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.onCancel,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive
                ? AppColorPalette.error
                : (confirmColor ?? Theme.of(context).primaryColor),
            foregroundColor: AppColorPalette.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// A reusable bottom sheet component
class CustomBottomSheet extends StatelessWidget {
  final String? title;
  final Widget content;
  final bool isScrollable;
  final double initialChildSize;
  final double maxChildSize;
  final double minChildSize;

  const CustomBottomSheet({
    super.key,
    this.title,
    required this.content,
    this.isScrollable = true,
    this.initialChildSize = 0.7,
    this.maxChildSize = 0.9,
    this.minChildSize = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      minChildSize: minChildSize,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
            ],
            if (isScrollable)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: content,
                ),
              )
            else
              Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// A reusable options bottom sheet
class OptionsBottomSheet extends StatelessWidget {
  final List<BottomSheetOption> options;

  const OptionsBottomSheet({super.key, required this.options});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...options.map(
          (option) => ListTile(
            leading: Icon(
              option.icon,
              color: option.isDestructive ? AppColorPalette.error : null,
            ),
            title: Text(
              option.title,
              style: TextStyle(color: option.isDestructive ? AppColorPalette.error : null),
            ),
            onTap: () {
              Navigator.pop(context);
              option.onTap();
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

/// Data class for bottom sheet options
class BottomSheetOption {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const BottomSheetOption({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

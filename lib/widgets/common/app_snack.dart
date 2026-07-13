import 'dart:math';

import 'package:flutter/material.dart';

/// Compact floating snack used across the app (⅓ width, small body text).
///
/// [duration] defaults to 1.5 seconds.
void showAppSnack(
  BuildContext context, {
  required String text,
  Duration duration = const Duration(milliseconds: 1500),
  bool clearPrevious = true,
  double widthFraction = 1 / 3,
}) {
  if (text.trim().isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final width = MediaQuery.sizeOf(context).width * widthFraction;
  final scheme = Theme.of(context).colorScheme;
  final style = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onInverseSurface,
      );

  if (clearPrevious) {
    messenger.hideCurrentSnackBar();
  }

  messenger.showSnackBar(
    SnackBar(
      width: width,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      content: Text(
        text,
        textAlign: TextAlign.center,
        style: style,
      ),
    ),
  );
}

/// Picks [text], or a random entry from [messages] when [text] is null/empty.
void showAppSnackMessage(
  BuildContext context, {
  String? text,
  List<String>? messages,
  Duration duration = const Duration(milliseconds: 1500),
  Random? random,
  bool clearPrevious = true,
  double widthFraction = 1 / 3,
}) {
  var message = text?.trim();
  if ((message == null || message.isEmpty) &&
      messages != null &&
      messages.isNotEmpty) {
    final rng = random ?? Random();
    message = messages[rng.nextInt(messages.length)];
  }
  if (message == null || message.isEmpty) return;
  showAppSnack(
    context,
    text: message,
    duration: duration,
    clearPrevious: clearPrevious,
    widthFraction: widthFraction,
  );
}

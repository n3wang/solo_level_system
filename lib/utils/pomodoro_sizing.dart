import 'package:flutter/material.dart';
import '../constants/pomodoro_constants.dart';

/// Utility functions for dynamic sizing calculations
class PomodoroSizing {
  /// Calculate dynamic album container size based on screen dimensions
  static double getAlbumContainerSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final calculatedSize = screenHeight * PomodoroConstants.albumSizeRatio;
    return calculatedSize > PomodoroConstants.minAlbumSize
        ? calculatedSize
        : PomodoroConstants.minAlbumSize;
  }

  /// Calculate dynamic font size based on container size
  static double getTimerFontSize(BuildContext context) {
    final containerSize = getAlbumContainerSize(context);
    return (containerSize / PomodoroConstants.baseContainerSize) *
        PomodoroConstants.baseFontSize;
  }

  /// Calculate music widget width
  static double getMusicWidgetWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final albumSize = getAlbumContainerSize(context);
    final availableWidth =
        screenWidth - albumSize - PomodoroConstants.musicWidgetSpacing;

    return availableWidth > PomodoroConstants.musicWidgetMaxWidth
        ? PomodoroConstants.musicWidgetMaxWidth
        : availableWidth.clamp(
            PomodoroConstants.musicWidgetMinWidth,
            PomodoroConstants.musicWidgetMaxWidth,
          );
  }

  /// Check if screen is wide enough for horizontal layout
  static bool shouldUseHorizontalLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >
        PomodoroConstants.responsiveBreakpoint;
  }

  /// Format time in MM:SS format
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Constants for the Pomodoro functionality
class PomodoroConstants {
  // Default values
  static const int defaultWorkMinutes = 25;
  static const int defaultBreakMinutes = 5;
  static const int defaultWorkSeconds = defaultWorkMinutes * 60;

  // UI Constants
  static const double minAlbumSize = 200.0;
  static const double maxAlbumSize = 500.0;
  static const double timerPadding = 40.0; // Padding from screen edges
  static const double albumSizeRatio = 0.5; // 50% of smaller screen dimension for square ratio
  static const double baseFontSize = 48.0;
  static const double baseContainerSize = 200.0;
  static const double musicWidgetMinWidth = 100.0;
  static const double musicWidgetMaxWidth = 150.0;
  static const double musicWidgetSpacing = 80.0;
  static const double responsiveBreakpoint = 600.0;

  // Gesture thresholds
  static const double swipeVelocityThreshold = 300.0;

  // Animation durations
  static const Duration autoStartDelay = Duration(seconds: 2);
  static const Duration timerUpdateInterval = Duration(seconds: 1);

  // Spacing and padding
  static const double defaultPadding = 24.0;
  static const double sectionSpacing = 20.0;
  static const double elementSpacing = 8.0;
  static const double borderRadius = 20.0;
  static const double smallBorderRadius = 12.0;
  static const double borderWidth = 2.0;

  // Session squares
  static const double sessionSquareSize = 8.0;
  static const double sessionSquareSpacing = 4.0;
  static const double sessionSquareBorderRadius = 2.0;
  static const double sessionSquareBorderWidth = 0.5;

  // Typography
  static const double timerInstructionFontSize = 10.0;
  static const double musicWidgetFontSize = 12.0;
  static const double musicInstructionFontSize = 8.0;

  // Colors - Now using centralized color palette
  // Import 'package:solo_level_system/constants/color_palette.dart' to access AppColorPalette
  // These constants map to the palette for backwards compatibility
  static const int greenPrimary = 0xFF4CAF50;  // AppColorPalette.color3 (green)
  static const int redPrimary = 0xFFF44336;    // AppColorPalette.color5 (red)
  static const int greyPrimary = 0xFF9E9E9E;   // AppColorPalette.grey
  static const int orangePrimary = 0xFFFF9800; // AppColorPalette.color4 (orange)
  static const int bluePrimary = 0xFF2196F3;   // AppColorPalette.color2 (blue)

  // Opacity values
  static const double backgroundOpacity = 0.3;
  static const double containerOpacity = 0.1;

  // Shadow
  static const double shadowBlurRadius = 10.0;
  static const double shadowOffset = 2.0;
  static const double smallShadowBlurRadius = 5.0;
  static const double smallShadowOffset = 1.0;
}

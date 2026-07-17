// lib/models/app_theme_model.dart
import 'package:flutter/material.dart';

/// Model for app theme configuration
class AppTheme {
  final String name;
  final ThemeColors colors;
  final ThemeBackgrounds backgrounds;
  final ThemeFonts fonts;
  final ThemeFontSizes fontSizes;

  AppTheme({
    required this.name,
    required this.colors,
    required this.backgrounds,
    required this.fonts,
    required this.fontSizes,
  });

  factory AppTheme.defaultTheme() {
    return AppTheme(
      name: 'default',
      colors: ThemeColors.defaultColors(),
      backgrounds: ThemeBackgrounds.defaultBackgrounds(),
      fonts: ThemeFonts.defaultFonts(),
      fontSizes: ThemeFontSizes.defaultSizes(),
    );
  }
}

/// Theme color configuration
class ThemeColors {
  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;
  final Color color5;

  ThemeColors({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
    required this.color5,
  });

  factory ThemeColors.defaultColors() {
    return ThemeColors(
      color1: const Color(0xFF9C27B0), // Purple
      color2: const Color(0xFF2196F3), // Blue
      color3: const Color(0xFF4CAF50), // Green
      color4: const Color(0xFFFF9800), // Orange
      color5: const Color(0xFFF44336), // Red
    );
  }
}

/// Theme background colors configuration
class ThemeBackgrounds {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color dark;
  final Color darkSecondary;
  final Color darkSurface;

  ThemeBackgrounds({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.dark,
    required this.darkSecondary,
    required this.darkSurface,
  });

  factory ThemeBackgrounds.defaultBackgrounds() {
    return ThemeBackgrounds(
      primary: const Color(0xFFFFFFFF), // White
      secondary: const Color(0xFFF5F5F5), // Light grey
      surface: const Color(0xFFFFFFFF), // White
      dark: const Color(0xFF121212), // Dark background
      darkSecondary: const Color(0xFF1E1E1E), // Slightly lighter dark
      darkSurface: const Color(0xFF2C2C2C), // Dark surface
    );
  }
}

/// Theme font configuration
class ThemeFonts {
  final String primary;
  final String secondary;
  final String monospace;

  ThemeFonts({
    required this.primary,
    required this.secondary,
    required this.monospace,
  });

  factory ThemeFonts.defaultFonts() {
    return ThemeFonts(
      primary: 'Roboto',
      secondary: 'Poppins',
      monospace: 'Courier',
    );
  }
}

/// Theme font sizes configuration
class ThemeFontSizes {
  final double small;
  final double medium;
  final double large;
  final double xSmall;
  final double xLarge;
  final double xxLarge;
  final double caption;
  final double body;
  final double subtitle;
  final double title;
  final double heading;
  final double display;

  ThemeFontSizes({
    required this.small,
    required this.medium,
    required this.large,
    required this.xSmall,
    required this.xLarge,
    required this.xxLarge,
    required this.caption,
    required this.body,
    required this.subtitle,
    required this.title,
    required this.heading,
    required this.display,
  });

  factory ThemeFontSizes.defaultSizes() {
    return ThemeFontSizes(
      small: 12.0,
      medium: 16.0,
      large: 24.0,
      xSmall: 10.8,
      xLarge: 28.8,
      xxLarge: 36.0,
      caption: 12.0,
      body: 16.0,
      subtitle: 15.0,
      title: 17.0,
      heading: 19.0,
      display: 36.0,
    );
  }
}

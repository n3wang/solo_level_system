// lib/constants/color_palette.dart
import 'package:flutter/material.dart';
import '../models/app_theme_model.dart';

/// Standard color palette for the application
/// This is the single source of truth for all colors used in the app
///
/// USAGE:
/// - For static colors: AppColorPalette.color1, AppColorPalette.success, etc.
/// - For dynamic theme colors: Use AppThemeProvider (see theme_loader.dart)
///
/// To change colors globally, edit assets/themes/themes.yaml
class AppColorPalette {
  // Private constructor to prevent instantiation
  AppColorPalette._();

  // Current active theme (can be set dynamically)
  static AppTheme? _activeTheme;

  // Current active palette name (defaults to creative)
  static String _activePaletteName = 'creative';

  // ============================================================================
  // PALETTE MANAGEMENT
  // ============================================================================

  /// Set the active palette by name
  static void setActivePalette(String paletteName) {
    _activePaletteName = paletteName;
  }

  /// Get the active palette name
  static String get activePaletteName => _activePaletteName;

  // ============================================================================
  // PRIMARY COLORS - From Active Palette
  // ============================================================================
  // All colors come from the active palette - no hardcoded colors

  /// Get color1 from active palette
  static Color get color1 => _getColorFromPalette(1);

  /// Get color2 from active palette
  static Color get color2 => _getColorFromPalette(2);

  /// Get color3 from active palette
  static Color get color3 => _getColorFromPalette(3);

  /// Get color4 from active palette
  static Color get color4 => _getColorFromPalette(4);

  /// Get color5 from active palette
  static Color get color5 => _getColorFromPalette(5);

  /// Get color from active palette by index (1-5)
  static Color _getColorFromPalette(int index) {
    switch (_activePaletteName) {
      case 'grayscale':
        switch (index) {
          case 1:
            return GrayscalePalette.color1;
          case 2:
            return GrayscalePalette.color2;
          case 3:
            return GrayscalePalette.color3;
          case 4:
            return GrayscalePalette.color4;
          case 5:
            return GrayscalePalette.color5;
        }
        break;
      case 'creative':
        switch (index) {
          case 1:
            return CreativePalette.color1;
          case 2:
            return CreativePalette.color2;
          case 3:
            return CreativePalette.color3;
          case 4:
            return CreativePalette.color4;
          case 5:
            return CreativePalette.color5;
        }
        break;
      case 'pastel':
        switch (index) {
          case 1:
            return PastelPalette.color1;
          case 2:
            return PastelPalette.color2;
          case 3:
            return PastelPalette.color3;
          case 4:
            return PastelPalette.color4;
          case 5:
            return PastelPalette.color5;
        }
        break;
      default:
        // Default to creative palette
        switch (index) {
          case 1:
            return CreativePalette.color1;
          case 2:
            return CreativePalette.color2;
          case 3:
            return CreativePalette.color3;
          case 4:
            return CreativePalette.color4;
          case 5:
            return CreativePalette.color5;
        }
    }
    return CreativePalette.color1; // Fallback
  }

  /// Get semantic color from active palette
  static Color _getSemanticColor(String semanticName) {
    switch (_activePaletteName) {
      case 'grayscale':
        switch (semanticName) {
          case 'primary':
            return GrayscalePalette.primary;
          case 'accent':
            return GrayscalePalette.accent;
          case 'background':
            return GrayscalePalette.background;
          case 'text':
            return GrayscalePalette.textColor;
        }
        break;
      case 'creative':
        switch (semanticName) {
          case 'primary':
            return CreativePalette.primary;
          case 'accent':
            return CreativePalette.accent;
          case 'background':
            return CreativePalette.background;
          case 'text':
            return CreativePalette.textColor;
        }
        break;
      case 'pastel':
        switch (semanticName) {
          case 'primary':
            return PastelPalette.primary;
          case 'accent':
            return PastelPalette.accent;
          case 'background':
            return PastelPalette.background;
          case 'text':
            return PastelPalette.textColor;
        }
        break;
      default:
        // Default to creative palette
        switch (semanticName) {
          case 'primary':
            return CreativePalette.primary;
          case 'accent':
            return CreativePalette.accent;
          case 'background':
            return CreativePalette.background;
          case 'text':
            return CreativePalette.textColor;
        }
    }
    return CreativePalette.primary; // Fallback
  }

  /// Get all colors from active palette as a list
  static List<Color> get allActiveColors => [
    color1,
    color2,
    color3,
    color4,
    color5,
  ];

  /// Get all palette colors as a list (indexed 0-4) - uses active palette
  static List<Color> get allColors => allActiveColors;

  /// Get colors from a specific palette by name
  static List<Color> getColorsFromPalette(String paletteName) {
    switch (paletteName) {
      case 'grayscale':
        return [
          GrayscalePalette.color1,
          GrayscalePalette.color2,
          GrayscalePalette.color3,
          GrayscalePalette.color4,
          GrayscalePalette.color5,
        ];
      case 'creative':
        return [
          CreativePalette.color1,
          CreativePalette.color2,
          CreativePalette.color3,
          CreativePalette.color4,
          CreativePalette.color5,
        ];
      case 'pastel':
        return [
          PastelPalette.color1,
          PastelPalette.color2,
          PastelPalette.color3,
          PastelPalette.color4,
          PastelPalette.color5,
        ];
      case 'default':
      default:
        return allColors;
    }
  }

  /// Get color by index (0-4), wraps around if index > 4
  static Color getColorByIndex(int index) {
    return allColors[index % allColors.length];
  }

  /// Get color by position (1-5), wraps around if position > 5
  static Color getColorByPosition(int position) {
    return getColorByIndex(position - 1);
  }

  // ============================================================================
  // SEMANTIC COLORS - From Active Palette
  // ============================================================================
  // All semantic colors come from the active palette

  /// Primary color from active palette
  static Color get primary => _getSemanticColor('primary');

  /// Accent color from active palette
  static Color get accent => _getSemanticColor('accent');

  /// Background color from active palette
  static Color get background => _getSemanticColor('background');

  /// Text color from active palette
  static Color get textColor => _getSemanticColor('text');

  /// Colors for states and feedback (mapped from palette colors)
  static Color get success => color3; // Typically green
  static Color get error => color5; // Typically red
  static Color get warning => color4; // Typically orange
  static Color get info => color2; // Typically blue

  /// Colors for priority levels (mapped from palette colors)
  static Color get priorityLow => color1;
  static Color get priorityMedium => color4;
  static Color get priorityHigh => color3;
  static Color get priorityUrgent => color5;

  // ============================================================================
  // NEUTRAL COLORS - From Active Palette
  // ============================================================================
  // Neutral colors come from the active palette's background/text colors
  // Grey shades are derived from the palette's background

  /// White color (pure white, used for contrast)
  static const Color white = Color(0xFFFFFFFF);

  /// Black color (pure black, used for contrast)
  static const Color black = Color(0xFF000000);

  /// Base grey color from active palette
  static Color get grey => _getGreyFromPalette();

  /// Get grey color from active palette
  static Color _getGreyFromPalette() {
    switch (_activePaletteName) {
      case 'grayscale':
        return GrayscalePalette.grey;
      case 'creative':
        return CreativePalette.grey;
      case 'pastel':
        return PastelPalette.grey;
      default:
        return CreativePalette.grey;
    }
  }

  // Grey shades - From active palette
  static Color get grey50 => _getGreyShade(50);
  static Color get grey100 => _getGreyShade(100);
  static Color get grey200 => _getGreyShade(200);
  static Color get grey300 => _getGreyShade(300);
  static Color get grey400 => _getGreyShade(400);
  static Color get grey500 => _getGreyShade(500);
  static Color get grey600 => _getGreyShade(600);
  static Color get grey700 => _getGreyShade(700);
  static Color get grey800 => _getGreyShade(800);
  static Color get grey900 => _getGreyShade(900);

  /// Get grey shade from active palette
  static Color _getGreyShade(int shade) {
    switch (_activePaletteName) {
      case 'grayscale':
        switch (shade) {
          case 50:
            return GrayscalePalette.grey50;
          case 100:
            return GrayscalePalette.grey100;
          case 200:
            return GrayscalePalette.grey200;
          case 300:
            return GrayscalePalette.grey300;
          case 400:
            return GrayscalePalette.grey400;
          case 500:
            return GrayscalePalette.grey500;
          case 600:
            return GrayscalePalette.grey600;
          case 700:
            return GrayscalePalette.grey700;
          case 800:
            return GrayscalePalette.grey800;
          case 900:
            return GrayscalePalette.grey900;
        }
        break;
      case 'creative':
        switch (shade) {
          case 50:
            return CreativePalette.grey50;
          case 100:
            return CreativePalette.grey100;
          case 200:
            return CreativePalette.grey200;
          case 300:
            return CreativePalette.grey300;
          case 400:
            return CreativePalette.grey400;
          case 500:
            return CreativePalette.grey500;
          case 600:
            return CreativePalette.grey600;
          case 700:
            return CreativePalette.grey700;
          case 800:
            return CreativePalette.grey800;
          case 900:
            return CreativePalette.grey900;
        }
        break;
      case 'pastel':
        switch (shade) {
          case 50:
            return PastelPalette.grey50;
          case 100:
            return PastelPalette.grey100;
          case 200:
            return PastelPalette.grey200;
          case 300:
            return PastelPalette.grey300;
          case 400:
            return PastelPalette.grey400;
          case 500:
            return PastelPalette.grey500;
          case 600:
            return PastelPalette.grey600;
          case 700:
            return PastelPalette.grey700;
          case 800:
            return PastelPalette.grey800;
          case 900:
            return PastelPalette.grey900;
        }
        break;
    }
    // Fallback to creative palette
    switch (shade) {
      case 50:
        return CreativePalette.grey50;
      case 100:
        return CreativePalette.grey100;
      case 200:
        return CreativePalette.grey200;
      case 300:
        return CreativePalette.grey300;
      case 400:
        return CreativePalette.grey400;
      case 500:
        return CreativePalette.grey500;
      case 600:
        return CreativePalette.grey600;
      case 700:
        return CreativePalette.grey700;
      case 800:
        return CreativePalette.grey800;
      case 900:
        return CreativePalette.grey900;
      default:
        return CreativePalette.grey500;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Convert color to hex string (for storage)
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Parse hex string to color (from storage)
  static Color? hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  /// Get a palette color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get a palette color with alpha value
  static Color withAlpha(Color color, int alpha) {
    return color.withAlpha(alpha);
  }

  /// Create a MaterialColor from a palette color
  /// This is useful for theme configuration that requires MaterialColor
  static MaterialColor toMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = (color.r * 255).round().clamp(0, 255);
    final int g = (color.g * 255).round().clamp(0, 255);
    final int b = (color.b * 255).round().clamp(0, 255);

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  /// Get MaterialColor variants of palette colors (from active palette)
  static MaterialColor get materialColor1 => toMaterialColor(color1);
  static MaterialColor get materialColor2 => toMaterialColor(color2);
  static MaterialColor get materialColor3 => toMaterialColor(color3);
  static MaterialColor get materialColor4 => toMaterialColor(color4);
  static MaterialColor get materialColor5 => toMaterialColor(color5);

  // ============================================================================
  // THEME SYSTEM INTEGRATION
  // ============================================================================

  /// Set the active theme (loads colors, fonts, backgrounds from theme)
  static void setActiveTheme(AppTheme theme) {
    _activeTheme = theme;
  }

  /// Get the currently active theme
  static AppTheme? get activeTheme => _activeTheme;

  /// Check if a theme is active
  static bool get hasActiveTheme => _activeTheme != null;

  // Theme-aware color getters (use active theme if set, otherwise use palette colors)
  static Color get themeColor1 => _activeTheme?.colors.color1 ?? color1;
  static Color get themeColor2 => _activeTheme?.colors.color2 ?? color2;
  static Color get themeColor3 => _activeTheme?.colors.color3 ?? color3;
  static Color get themeColor4 => _activeTheme?.colors.color4 ?? color4;
  static Color get themeColor5 => _activeTheme?.colors.color5 ?? color5;

  // Theme backgrounds (use active theme if set, otherwise use palette background)
  static Color get backgroundPrimary =>
      _activeTheme?.backgrounds.primary ?? background;
  static Color get backgroundSecondary =>
      _activeTheme?.backgrounds.secondary ?? grey100;
  static Color get backgroundSurface =>
      _activeTheme?.backgrounds.surface ?? background;
  static Color get backgroundDark => _activeTheme?.backgrounds.dark ?? black;
  static Color get backgroundDarkSecondary =>
      _activeTheme?.backgrounds.darkSecondary ?? grey900;
  static Color get backgroundDarkSurface =>
      _activeTheme?.backgrounds.darkSurface ?? grey800;

  // Convenience getter for scaffold background (uses palette background)
  static Color get scaffoldBackground => background;

  // Theme fonts
  static String get fontPrimary => _activeTheme?.fonts.primary ?? 'Roboto';
  static String get fontSecondary => _activeTheme?.fonts.secondary ?? 'Poppins';
  static String get fontMonospace => _activeTheme?.fonts.monospace ?? 'Courier';

  // Theme font sizes
  static double get fontSizeSmall => _activeTheme?.fontSizes.small ?? 12.0;
  static double get fontSizeMedium => _activeTheme?.fontSizes.medium ?? 16.0;
  static double get fontSizeLarge => _activeTheme?.fontSizes.large ?? 24.0;

  // Derived font sizes
  static double get fontSizeXSmall => _activeTheme?.fontSizes.xSmall ?? 10.8;
  static double get fontSizeXLarge => _activeTheme?.fontSizes.xLarge ?? 28.8;
  static double get fontSizeXXLarge => _activeTheme?.fontSizes.xxLarge ?? 36.0;
  static double get fontSizeCaption => _activeTheme?.fontSizes.caption ?? 12.0;
  static double get fontSizeBody => _activeTheme?.fontSizes.body ?? 16.0;
  static double get fontSizeSubtitle =>
      _activeTheme?.fontSizes.subtitle ?? 18.0;
  static double get fontSizeTitle => _activeTheme?.fontSizes.title ?? 21.0;
  static double get fontSizeHeading => _activeTheme?.fontSizes.heading ?? 24.0;
  static double get fontSizeDisplay => _activeTheme?.fontSizes.display ?? 36.0;
}

// ============================================================================
// ALTERNATIVE PALETTES
// ============================================================================
// Define alternative color palettes here if needed
// To switch palettes, change the values in AppColorPalette to reference these

/// Grayscale palette - 5 shades of grey
class GrayscalePalette {
  // Primary colors
  static const Color color1 = Color(0xFF212121); // Dark grey
  static const Color color2 = Color(0xFF424242); // Medium-dark grey
  static const Color color3 = Color(0xFF757575); // Medium grey
  static const Color color4 = Color(0xFF9E9E9E); // Light-medium grey
  static const Color color5 = Color(0xFFBDBDBD); // Light grey

  // Semantic colors
  static const Color primary = Color(0xFF212121); // Dark grey as primary
  static const Color accent = Color(0xFF424242); // Medium-dark grey as accent
  static const Color background = Color(
    0xFFFAFAFA,
  ); // Very light grey background
  static const Color textColor = Color(0xFF212121); // Dark grey text

  // Grey shades
  static const Color grey = Color(0xFF9E9E9E);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
}

/// Creative color palette (renamed from Original)
/// Vibrant, creative colors for a bold look
class CreativePalette {
  // Primary colors
  static const Color color1 = Color(0xFF9C27B0); // Purple
  static const Color color2 = Color(0xFF2196F3); // Blue
  static const Color color3 = Color(0xFF4CAF50); // Green
  static const Color color4 = Color(0xFFFF9800); // Orange
  static const Color color5 = Color(0xFFF44336); // Red

  // Semantic colors
  static const Color primary = Color(0xFF9C27B0); // Purple as primary
  static const Color accent = Color(0xFF2196F3); // Blue as accent
  static const Color background = Color(0xFFFFFFFF); // White background
  static const Color textColor = Color(0xFF212121); // Dark grey text

  // Grey shades - Updated to cooler, more neutral grey tones
  static const Color grey = Color(0xFF8E8E93);
  static const Color grey50 = Color(0xFFF8F9FA);
  static const Color grey100 = Color(0xFFF1F3F5);
  static const Color grey200 = Color(0xFFE9ECEF);
  static const Color grey300 = Color(0xFFDEE2E6);
  static const Color grey400 = Color(0xFFCED4DA);
  static const Color grey500 = Color(0xFF8E8E93);
  static const Color grey600 = Color(0xFF6C757D);
  static const Color grey700 = Color(0xFF5A6268);
  static const Color grey800 = Color(0xFF495057);
  static const Color grey900 = Color(0xFF343A40);
}

/// Pastel color palette
/// Soft, muted colors for a gentle look
class PastelPalette {
  // Primary colors
  static const Color color1 = Color(0xFFEF9A9A); // Light Red // Light Purple
  static const Color color2 = Color(0xFF90CAF9); // Light Blue
  static const Color color3 = Color(0xFFA5D6A7); // Light Green
  static const Color color4 = Color(0xFFFFCC80); // Light Orange
  static const Color color5 = Color(0xFFCE93D8);

  // Semantic colors
  static const Color primary = Color(0xFFEF9A9A); // Light Purple as primary
  static const Color accent = Color(0xFF90CAF9); // Light Blue as accent
  static const Color background = Color(
    0xFFFFFBFE,
  ); // Very light pink/white background
  static const Color textColor = Color(
    0xFF4A4A4A,
  ); // Medium grey text for readability

  // Grey shades - Softer, warmer greys for pastel theme
  static const Color grey = Color(0xFFB0B0B0);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFFB0B0B0);
  static const Color grey600 = Color(0xFF9E9E9E);
  static const Color grey700 = Color(0xFF757575);
  static const Color grey800 = Color(0xFF616161);
  static const Color grey900 = Color(0xFF424242);
}

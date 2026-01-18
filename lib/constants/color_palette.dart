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

  // ============================================================================
  // PRIMARY PALETTE - 5 Standard Colors
  // ============================================================================
  // These are the 5 core colors that MUST be used throughout the app

  static const Color color1 = Color(0xFF9C27B0); // Purple
  static const Color color2 = Color(0xFF2196F3); // Blue
  static const Color color3 = Color(0xFF4CAF50); // Green
  static const Color color4 = Color(0xFFFF9800); // Orange
  static const Color color5 = Color(0xFFF44336); // Red

  /// Get all palette colors as a list (indexed 0-4)
  static List<Color> get allColors => [
        color1,
        color2,
        color3,
        color4,
        color5,
      ];

  /// Get color by index (0-4), wraps around if index > 4
  static Color getColorByIndex(int index) {
    return allColors[index % allColors.length];
  }

  /// Get color by position (1-5), wraps around if position > 5
  static Color getColorByPosition(int position) {
    return getColorByIndex(position - 1);
  }

  // ============================================================================
  // SEMANTIC COLOR MAPPINGS
  // ============================================================================
  // Map semantic meanings to palette colors for consistency

  /// Colors for states and feedback
  static const Color success = color3; // Green
  static const Color error = color5; // Red
  static const Color warning = color4; // Orange
  static const Color info = color2; // Blue
  static const Color primary = color1; // Purple

  /// Colors for priority levels
  static const Color priorityLow = color1; // Purple
  static const Color priorityMedium = color4; // Orange
  static const Color priorityHigh = color3; // Green
  static const Color priorityUrgent = color5; // Red

  // ============================================================================
  // NEUTRAL COLORS
  // ============================================================================
  // Neutral colors that complement the palette

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);

  // Grey shades
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

  /// Get MaterialColor variants of palette colors
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

  // Theme-aware color getters (use active theme if set, otherwise use static colors)
  static Color get themeColor1 => _activeTheme?.colors.color1 ?? color1;
  static Color get themeColor2 => _activeTheme?.colors.color2 ?? color2;
  static Color get themeColor3 => _activeTheme?.colors.color3 ?? color3;
  static Color get themeColor4 => _activeTheme?.colors.color4 ?? color4;
  static Color get themeColor5 => _activeTheme?.colors.color5 ?? color5;

  // Theme backgrounds
  static Color get backgroundPrimary =>
      _activeTheme?.backgrounds.primary ?? white;
  static Color get backgroundSecondary =>
      _activeTheme?.backgrounds.secondary ?? grey100;
  static Color get backgroundSurface =>
      _activeTheme?.backgrounds.surface ?? white;
  static Color get backgroundDark => _activeTheme?.backgrounds.dark ?? black;
  static Color get backgroundDarkSecondary =>
      _activeTheme?.backgrounds.darkSecondary ?? grey900;
  static Color get backgroundDarkSurface =>
      _activeTheme?.backgrounds.darkSurface ?? grey800;

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
  static double get fontSizeSubtitle => _activeTheme?.fontSizes.subtitle ?? 18.0;
  static double get fontSizeTitle => _activeTheme?.fontSizes.title ?? 21.0;
  static double get fontSizeHeading => _activeTheme?.fontSizes.heading ?? 24.0;
  static double get fontSizeDisplay => _activeTheme?.fontSizes.display ?? 36.0;
}

// ============================================================================
// ALTERNATIVE PALETTES
// ============================================================================
// Define alternative color palettes here if needed
// To switch palettes, change the values in AppColorPalette to reference these

/// Warm color palette
class WarmPalette {
  static const Color color1 = Color(0xFFE91E63); // Pink
  static const Color color2 = Color(0xFFFF5722); // Deep Orange
  static const Color color3 = Color(0xFFFFEB3B); // Yellow
  static const Color color4 = Color(0xFFFF9800); // Orange
  static const Color color5 = Color(0xFFF44336); // Red
}

/// Cool color palette
class CoolPalette {
  static const Color color1 = Color(0xFF3F51B5); // Indigo
  static const Color color2 = Color(0xFF2196F3); // Blue
  static const Color color3 = Color(0xFF00BCD4); // Cyan
  static const Color color4 = Color(0xFF009688); // Teal
  static const Color color5 = Color(0xFF4CAF50); // Green
}

/// Earth tone palette
class EarthPalette {
  static const Color color1 = Color(0xFF795548); // Brown
  static const Color color2 = Color(0xFF8D6E63); // Light Brown
  static const Color color3 = Color(0xFF689F38); // Olive Green
  static const Color color4 = Color(0xFFFF9800); // Orange
  static const Color color5 = Color(0xFFD32F2F); // Dark Red
}

/// Pastel color palette
class PastelPalette {
  static const Color color1 = Color(0xFFCE93D8); // Light Purple
  static const Color color2 = Color(0xFF90CAF9); // Light Blue
  static const Color color3 = Color(0xFFA5D6A7); // Light Green
  static const Color color4 = Color(0xFFFFCC80); // Light Orange
  static const Color color5 = Color(0xFFEF9A9A); // Light Red
}

/// Vibrant color palette
class VibrantPalette {
  static const Color color1 = Color(0xFF9C27B0); // Purple
  static const Color color2 = Color(0xFF00BCD4); // Cyan
  static const Color color3 = Color(0xFF8BC34A); // Light Green
  static const Color color4 = Color(0xFFFFEB3B); // Yellow
  static const Color color5 = Color(0xFFFF5722); // Deep Orange
}

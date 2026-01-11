// lib/models/app_theme_model.dart
import 'package:flutter/material.dart';

/// Represents a complete app theme configuration
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

  factory AppTheme.fromMap(Map<dynamic, dynamic> map) {
    return AppTheme(
      name: map['name'] ?? 'Unnamed Theme',
      colors: ThemeColors.fromMap(map['colors'] ?? {}),
      backgrounds: ThemeBackgrounds.fromMap(map['backgrounds'] ?? {}),
      fonts: ThemeFonts.fromMap(map['fonts'] ?? {}),
      fontSizes: ThemeFontSizes.fromMap(map['fontSizes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colors': colors.toMap(),
      'backgrounds': backgrounds.toMap(),
      'fonts': fonts.toMap(),
      'fontSizes': fontSizes.toMap(),
    };
  }
}

/// Theme colors (5 core colors)
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

  factory ThemeColors.fromMap(Map<dynamic, dynamic> map) {
    return ThemeColors(
      color1: _parseColor(map['color1'], const Color(0xFF9C27B0)),
      color2: _parseColor(map['color2'], const Color(0xFF2196F3)),
      color3: _parseColor(map['color3'], const Color(0xFF4CAF50)),
      color4: _parseColor(map['color4'], const Color(0xFFFF9800)),
      color5: _parseColor(map['color5'], const Color(0xFFF44336)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'color1': _colorToHex(color1),
      'color2': _colorToHex(color2),
      'color3': _colorToHex(color3),
      'color4': _colorToHex(color4),
      'color5': _colorToHex(color5),
    };
  }

  List<Color> toList() => [color1, color2, color3, color4, color5];

  static Color _parseColor(dynamic value, Color defaultColor) {
    if (value == null) return defaultColor;
    try {
      String hex = value.toString().replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return defaultColor;
    }
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

/// Theme background colors
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

  factory ThemeBackgrounds.fromMap(Map<dynamic, dynamic> map) {
    return ThemeBackgrounds(
      primary: ThemeColors._parseColor(
        map['primary'],
        const Color(0xFFFFFFFF),
      ),
      secondary: ThemeColors._parseColor(
        map['secondary'],
        const Color(0xFFF5F5F5),
      ),
      surface: ThemeColors._parseColor(
        map['surface'],
        const Color(0xFFFFFFFF),
      ),
      dark: ThemeColors._parseColor(
        map['dark'],
        const Color(0xFF121212),
      ),
      darkSecondary: ThemeColors._parseColor(
        map['darkSecondary'],
        const Color(0xFF1E1E1E),
      ),
      darkSurface: ThemeColors._parseColor(
        map['darkSurface'],
        const Color(0xFF2C2C2C),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primary': ThemeColors._colorToHex(primary),
      'secondary': ThemeColors._colorToHex(secondary),
      'surface': ThemeColors._colorToHex(surface),
      'dark': ThemeColors._colorToHex(dark),
      'darkSecondary': ThemeColors._colorToHex(darkSecondary),
      'darkSurface': ThemeColors._colorToHex(darkSurface),
    };
  }
}

/// Theme font families (3 fonts)
class ThemeFonts {
  final String primary;
  final String secondary;
  final String monospace;

  ThemeFonts({
    required this.primary,
    required this.secondary,
    required this.monospace,
  });

  factory ThemeFonts.fromMap(Map<dynamic, dynamic> map) {
    return ThemeFonts(
      primary: map['primary']?.toString() ?? 'Roboto',
      secondary: map['secondary']?.toString() ?? 'Poppins',
      monospace: map['monospace']?.toString() ?? 'Courier',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primary': primary,
      'secondary': secondary,
      'monospace': monospace,
    };
  }
}

/// Theme font sizes (3 base sizes)
class ThemeFontSizes {
  final double small;
  final double medium;
  final double large;

  ThemeFontSizes({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory ThemeFontSizes.fromMap(Map<dynamic, dynamic> map) {
    return ThemeFontSizes(
      small: _parseDouble(map['small'], 12.0),
      medium: _parseDouble(map['medium'], 16.0),
      large: _parseDouble(map['large'], 24.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'small': small,
      'medium': medium,
      'large': large,
    };
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  // Derived font sizes for consistency
  double get xSmall => small * 0.9;
  double get xLarge => large * 1.2;
  double get xxLarge => large * 1.5;

  // Common UI element sizes
  double get caption => small;
  double get body => medium;
  double get subtitle => medium * 1.125;
  double get title => large * 0.875;
  double get heading => large;
  double get display => large * 1.5;
}

// lib/utils/theme_loader.dart
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/app_theme_model.dart';

/// Loads themes from the YAML configuration file
class ThemeLoader {
  static Map<String, AppTheme>? _cachedThemes;
  static const String _themesPath = 'assets/themes/themes.yaml';

  /// Load all themes from the YAML file
  static Future<Map<String, AppTheme>> loadThemes() async {
    // Return cached themes if available
    if (_cachedThemes != null) {
      return _cachedThemes!;
    }

    try {
      // Load the YAML file
      final String yamlString = await rootBundle.loadString(_themesPath);
      final dynamic yamlMap = loadYaml(yamlString);

      if (yamlMap is! Map) {
        throw Exception('Invalid YAML format: root must be a map');
      }

      // Parse each theme
      final Map<String, AppTheme> themes = {};
      yamlMap.forEach((key, value) {
        if (value is Map) {
          themes[key.toString()] = AppTheme.fromMap(value);
        }
      });

      _cachedThemes = themes;
      return themes;
    } catch (e) {
      print('Error loading themes: $e');
      // Return default theme if loading fails
      return {
        'default': _getDefaultTheme(),
      };
    }
  }

  /// Load a specific theme by key
  static Future<AppTheme> loadTheme(String themeKey) async {
    final themes = await loadThemes();
    return themes[themeKey] ?? themes['default'] ?? _getDefaultTheme();
  }

  /// Get the default theme (fallback)
  static AppTheme _getDefaultTheme() {
    return AppTheme(
      name: 'Default',
      colors: ThemeColors(
        color1: const Color(0xFF9C27B0),
        color2: const Color(0xFF2196F3),
        color3: const Color(0xFF4CAF50),
        color4: const Color(0xFFFF9800),
        color5: const Color(0xFFF44336),
      ),
      backgrounds: ThemeBackgrounds(
        primary: const Color(0xFFFFFFFF),
        secondary: const Color(0xFFF5F5F5),
        surface: const Color(0xFFFFFFFF),
        dark: const Color(0xFF121212),
        darkSecondary: const Color(0xFF1E1E1E),
        darkSurface: const Color(0xFF2C2C2C),
      ),
      fonts: ThemeFonts(
        primary: 'Roboto',
        secondary: 'Poppins',
        monospace: 'Courier',
      ),
      fontSizes: ThemeFontSizes(
        small: 12.0,
        medium: 16.0,
        large: 24.0,
      ),
    );
  }

  /// Get list of available theme keys
  static Future<List<String>> getThemeKeys() async {
    final themes = await loadThemes();
    return themes.keys.toList();
  }

  /// Get list of available theme names
  static Future<List<String>> getThemeNames() async {
    final themes = await loadThemes();
    return themes.values.map((theme) => theme.name).toList();
  }

  /// Clear cached themes (useful for hot reload during development)
  static void clearCache() {
    _cachedThemes = null;
  }

  /// Reload themes from file
  static Future<Map<String, AppTheme>> reloadThemes() async {
    clearCache();
    return loadThemes();
  }
}

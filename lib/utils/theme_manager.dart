// lib/utils/theme_manager.dart
import '../constants/color_palette.dart';
import '../models/app_theme_model.dart';
import 'theme_loader.dart';

/// Manages theme loading and switching for the application
class ThemeManager {
  static AppTheme? _currentTheme;
  static String _currentThemeKey = 'default';

  /// Initialize the theme system
  /// Call this in main() before runApp()
  static Future<void> initialize({String themeKey = 'default'}) async {
    try {
      final theme = await ThemeLoader.loadTheme(themeKey);
      await setTheme(theme, themeKey);
      print('✓ Theme initialized: ${theme.name}');
    } catch (e) {
      print('✗ Failed to initialize theme: $e');
      // App will use default static colors if theme fails to load
    }
  }

  /// Set the current theme
  static Future<void> setTheme(AppTheme theme, String themeKey) async {
    _currentTheme = theme;
    _currentThemeKey = themeKey;
    AppColorPalette.setActiveTheme(theme);
  }

  /// Switch to a different theme by key
  static Future<bool> switchTheme(String themeKey) async {
    try {
      final theme = await ThemeLoader.loadTheme(themeKey);
      await setTheme(theme, themeKey);
      print('✓ Switched to theme: ${theme.name}');
      return true;
    } catch (e) {
      print('✗ Failed to switch theme: $e');
      return false;
    }
  }

  /// Get the current theme
  static AppTheme? get currentTheme => _currentTheme;

  /// Get the current theme key
  static String get currentThemeKey => _currentThemeKey;

  /// Get all available theme keys
  static Future<List<String>> getAvailableThemes() async {
    return await ThemeLoader.getThemeKeys();
  }

  /// Get all available theme names
  static Future<List<String>> getAvailableThemeNames() async {
    return await ThemeLoader.getThemeNames();
  }

  /// Reload themes from file (useful for development)
  static Future<void> reloadThemes() async {
    await ThemeLoader.reloadThemes();
    if (_currentThemeKey.isNotEmpty) {
      await switchTheme(_currentThemeKey);
    }
  }

  /// Get a map of theme keys to names
  static Future<Map<String, String>> getThemeMap() async {
    final themes = await ThemeLoader.loadThemes();
    return themes.map((key, theme) => MapEntry(key, theme.name));
  }
}

/// Example usage:
///
/// In main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await ThemeManager.initialize(themeKey: 'default');
///   runApp(MyApp());
/// }
/// ```
///
/// To switch themes:
/// ```dart
/// await ThemeManager.switchTheme('warm');
/// setState(() {}); // Trigger rebuild
/// ```
///
/// To use theme colors:
/// ```dart
/// // Use static colors (backwards compatible)
/// Container(color: AppColorPalette.color1);
///
/// // Use theme-aware colors
/// Container(color: AppColorPalette.themeColor1);
///
/// // Use theme fonts
/// Text('Hello', style: TextStyle(
///   fontFamily: AppColorPalette.fontPrimary,
///   fontSize: AppColorPalette.fontSizeMedium,
/// ));
///
/// // Use theme backgrounds
/// Scaffold(backgroundColor: AppColorPalette.backgroundPrimary);
/// ```

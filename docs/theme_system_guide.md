# Theme System Guide

## Overview

The app now features a comprehensive theme system that manages colors, fonts, font sizes, and background colors through a single YAML file. This makes it incredibly easy to customize the entire app's appearance without touching any code.

## Quick Start

### 1. Edit Themes

Open `assets/themes/themes.yaml` and edit any theme:

```yaml
default:
  name: "Default"
  colors:
    color1: "#9C27B0"  # Purple
    color2: "#2196F3"  # Blue
    color3: "#4CAF50"  # Green
    color4: "#FF9800"  # Orange
    color5: "#F44336"  # Red
  backgrounds:
    primary: "#FFFFFF"
    secondary: "#F5F5F5"
    # ... more backgrounds
  fonts:
    primary: "Roboto"
    secondary: "Poppins"
    monospace: "Courier"
  fontSizes:
    small: 12.0
    medium: 16.0
    large: 24.0
```

### 2. Initialize Theme

In your `main.dart`:

```dart
import 'package:solo_level_system/utils/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with a theme
  await ThemeManager.initialize(themeKey: 'default');

  runApp(MyApp());
}
```

### 3. Use Theme Values

```dart
import 'package:solo_level_system/constants/color_palette.dart';

// Colors
Container(color: AppColorPalette.themeColor1);
Container(color: AppColorPalette.backgroundPrimary);

// Fonts
Text('Hello', style: TextStyle(
  fontFamily: AppColorPalette.fontPrimary,
  fontSize: AppColorPalette.fontSizeMedium,
));
```

## Theme Structure

Each theme in the YAML file must include:

### 1. Theme Name
```yaml
name: "Theme Name"
```

### 2. Five Core Colors
```yaml
colors:
  color1: "#HEX"  # Purple/Primary
  color2: "#HEX"  # Blue/Info
  color3: "#HEX"  # Green/Success
  color4: "#HEX"  # Orange/Warning
  color5: "#HEX"  # Red/Error
```

### 3. Background Colors
```yaml
backgrounds:
  primary: "#HEX"          # Main background (light mode)
  secondary: "#HEX"        # Secondary background
  surface: "#HEX"          # Card/surface background
  dark: "#HEX"             # Main background (dark mode)
  darkSecondary: "#HEX"    # Secondary background (dark)
  darkSurface: "#HEX"      # Card/surface (dark)
```

### 4. Three Font Families
```yaml
fonts:
  primary: "Font Name"     # Main text font
  secondary: "Font Name"   # Headings/titles
  monospace: "Font Name"   # Code/monospace text
```

### 5. Three Font Sizes
```yaml
fontSizes:
  small: 12.0   # Small text (captions, hints)
  medium: 16.0  # Body text
  large: 24.0   # Headings
```

## Available Pre-Defined Themes

The YAML file includes 9 pre-defined themes:

1. **default** - Standard purple/blue theme
2. **warm** - Warm sunset colors (pink, orange, yellow)
3. **cool** - Cool ocean colors (indigo, blue, cyan, teal)
4. **earth** - Earth tones (brown, olive, orange)
5. **pastel** - Soft pastel colors
6. **vibrant** - High energy vibrant colors
7. **minimal** - Minimalist black and grey
8. **nature** - Forest green theme
9. **neon** - Neon nights theme

## API Reference

### ThemeManager

Main class for managing themes.

#### Methods

```dart
// Initialize theme system (call in main())
await ThemeManager.initialize(themeKey: 'default');

// Switch to a different theme
await ThemeManager.switchTheme('warm');

// Get current theme
AppTheme? theme = ThemeManager.currentTheme;

// Get current theme key
String key = ThemeManager.currentThemeKey;

// Get available theme keys
List<String> keys = await ThemeManager.getAvailableThemes();

// Get available theme names
List<String> names = await ThemeManager.getAvailableThemeNames();

// Get map of keys to names
Map<String, String> themes = await ThemeManager.getThemeMap();

// Reload themes (useful for development)
await ThemeManager.reloadThemes();
```

### AppColorPalette

Access theme values throughout your app.

#### Colors

```dart
// Theme-aware colors (use these for dynamic themes)
AppColorPalette.themeColor1  // Purple/Primary
AppColorPalette.themeColor2  // Blue/Info
AppColorPalette.themeColor3  // Green/Success
AppColorPalette.themeColor4  // Orange/Warning
AppColorPalette.themeColor5  // Red/Error

// Static colors (backwards compatible, don't change with theme)
AppColorPalette.color1  // Static purple
AppColorPalette.color2  // Static blue
// ... etc

// Semantic colors (static)
AppColorPalette.success   // Green
AppColorPalette.error     // Red
AppColorPalette.warning   // Orange
AppColorPalette.info      // Blue
AppColorPalette.primary   // Purple

// Backgrounds (theme-aware)
AppColorPalette.backgroundPrimary
AppColorPalette.backgroundSecondary
AppColorPalette.backgroundSurface
AppColorPalette.backgroundDark
AppColorPalette.backgroundDarkSecondary
AppColorPalette.backgroundDarkSurface

// Grey scale (static)
AppColorPalette.grey50  // Lightest
AppColorPalette.grey100
// ... through grey900
AppColorPalette.grey900  // Darkest

// White/Black (static)
AppColorPalette.white
AppColorPalette.black
AppColorPalette.grey
```

#### Fonts

```dart
// Font families (theme-aware)
AppColorPalette.fontPrimary    // Main text font
AppColorPalette.fontSecondary  // Headings/titles
AppColorPalette.fontMonospace  // Code/monospace
```

#### Font Sizes

```dart
// Base sizes (theme-aware)
AppColorPalette.fontSizeSmall   // 12.0 (default)
AppColorPalette.fontSizeMedium  // 16.0 (default)
AppColorPalette.fontSizeLarge   // 24.0 (default)

// Derived sizes
AppColorPalette.fontSizeXSmall    // small * 0.9
AppColorPalette.fontSizeXLarge    // large * 1.2
AppColorPalette.fontSizeXXLarge   // large * 1.5

// Semantic sizes
AppColorPalette.fontSizeCaption   // Same as small
AppColorPalette.fontSizeBody      // Same as medium
AppColorPalette.fontSizeSubtitle  // medium * 1.125
AppColorPalette.fontSizeTitle     // large * 0.875
AppColorPalette.fontSizeHeading   // Same as large
AppColorPalette.fontSizeDisplay   // large * 1.5
```

## Usage Examples

### Basic Color Usage

```dart
Container(
  color: AppColorPalette.themeColor1,
  child: Text(
    'Hello',
    style: TextStyle(
      color: AppColorPalette.white,
    ),
  ),
)
```

### Background Colors

```dart
Scaffold(
  backgroundColor: AppColorPalette.backgroundPrimary,
  appBar: AppBar(
    backgroundColor: AppColorPalette.themeColor1,
  ),
  body: Card(
    color: AppColorPalette.backgroundSurface,
    child: Text('Content'),
  ),
)
```

### Typography with Theme Fonts

```dart
Text(
  'Heading',
  style: TextStyle(
    fontFamily: AppColorPalette.fontSecondary,
    fontSize: AppColorPalette.fontSizeHeading,
    fontWeight: FontWeight.bold,
  ),
)

Text(
  'Body text',
  style: TextStyle(
    fontFamily: AppColorPalette.fontPrimary,
    fontSize: AppColorPalette.fontSizeBody,
  ),
)

Text(
  'Code snippet',
  style: TextStyle(
    fontFamily: AppColorPalette.fontMonospace,
    fontSize: AppColorPalette.fontSizeSmall,
  ),
)
```

### Dynamic Theme Switching

```dart
class ThemeSwitcher extends StatefulWidget {
  @override
  _ThemeSwitcherState createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {
  String currentTheme = 'default';

  Future<void> switchTheme(String themeKey) async {
    bool success = await ThemeManager.switchTheme(themeKey);
    if (success) {
      setState(() {
        currentTheme = themeKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: currentTheme,
      items: [
        DropdownMenuItem(value: 'default', child: Text('Default')),
        DropdownMenuItem(value: 'warm', child: Text('Warm')),
        DropdownMenuItem(value: 'cool', child: Text('Cool')),
      ],
      onChanged: (value) {
        if (value != null) {
          switchTheme(value);
        }
      },
    );
  }
}
```

## Creating Custom Themes

### Add to YAML

Add a new theme to `assets/themes/themes.yaml`:

```yaml
mytheme:
  name: "My Custom Theme"
  colors:
    color1: "#FF6B6B"  # Custom color 1
    color2: "#4ECDC4"  # Custom color 2
    color3: "#45B7D1"  # Custom color 3
    color4: "#FFA07A"  # Custom color 4
    color5: "#FF1744"  # Custom color 5
  backgrounds:
    primary: "#FFFFFF"
    secondary: "#F8F9FA"
    surface: "#FFFFFF"
    dark: "#1A1A1A"
    darkSecondary: "#2A2A2A"
    darkSurface: "#3A3A3A"
  fonts:
    primary: "Arial"
    secondary: "Georgia"
    monospace: "Courier New"
  fontSizes:
    small: 11.0
    medium: 15.0
    large: 22.0
```

### Use Your Theme

```dart
await ThemeManager.initialize(themeKey: 'mytheme');
```

## Migration from Old System

If you were using the old `AppColorPalette.color1` static approach:

### Before
```dart
Container(color: AppColorPalette.color1);
```

### After (Theme-Aware)
```dart
Container(color: AppColorPalette.themeColor1);
```

### Or Keep Backwards Compatible
```dart
// This still works! Uses static purple color
Container(color: AppColorPalette.color1);
```

## Best Practices

1. **Use Theme-Aware Colors** - Use `themeColor1` instead of `color1` for dynamic themes
2. **Use Semantic Names** - Use `success`, `error`, `warning` for state colors
3. **Use Theme Fonts** - Use `fontPrimary` for consistent typography
4. **Use Theme Sizes** - Use `fontSizeBody` for consistent sizing
5. **Test Dark Mode** - Make sure your backgrounds work in both light and dark
6. **Keep Themes Consistent** - All themes should have similar contrast ratios

## Troubleshooting

### Theme Not Loading

If themes don't load:
- Check that `assets/themes/` is in `pubspec.yaml` assets
- Verify YAML syntax is correct
- Check console for error messages
- Ensure `ThemeManager.initialize()` is called before `runApp()`

### Colors Not Changing

If colors don't update when switching themes:
- Call `setState(() {})` after switching themes
- Use `themeColor1` not `color1` (static colors don't change)
- Check that theme was successfully loaded

### Fonts Not Showing

If custom fonts don't appear:
- Use system font names (Arial, Helvetica, etc.)
- For custom fonts, add them to `pubspec.yaml` fonts section
- Fallback to default if font doesn't exist

## File Structure

```
lib/
├── constants/
│   └── color_palette.dart       # Color palette with theme integration
├── models/
│   └── app_theme_model.dart     # Theme data models
└── utils/
    ├── theme_loader.dart         # YAML theme loader
    └── theme_manager.dart        # Theme management

assets/
└── themes/
    └── themes.yaml               # Single file for all themes
```

## Notes

- Themes are cached after first load for performance
- Hot reload may require calling `ThemeManager.reloadThemes()`
- All color values in YAML must be hex format: `"#RRGGBB"`
- Font sizes are in logical pixels (dp/pt)
- System fonts don't need to be installed, custom fonts do

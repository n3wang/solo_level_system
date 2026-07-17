# Color Palette System Guide

## Overview

This application uses a centralized color palette system defined in `lib/constants/color_palette.dart`. All colors throughout the app MUST use this palette to ensure consistency and easy theme switching.

## Standard Palette

The app uses a standard palette of 5 core colors:

1. **Color 1 (Purple)** - `#9C27B0` - Primary/Accent
2. **Color 2 (Blue)** - `#2196F3` - Info/Secondary
3. **Color 3 (Green)** - `#4CAF50` - Success
4. **Color 4 (Orange)** - `#FF9800` - Warning
5. **Color 5 (Red)** - `#F44336` - Error/Danger

## Usage

### Basic Colors

```dart
import 'package:solo_level_system/constants/color_palette.dart';

// Use individual colors
Container(color: AppColorPalette.color1); // Purple
Container(color: AppColorPalette.color2); // Blue
Container(color: AppColorPalette.color3); // Green
Container(color: AppColorPalette.color4); // Orange
Container(color: AppColorPalette.color5); // Red
```

### Semantic Colors

Use semantic color names for better code readability:

```dart
// State colors
Container(color: AppColorPalette.success);  // Green
Container(color: AppColorPalette.error);    // Red
Container(color: AppColorPalette.warning);  // Orange
Container(color: AppColorPalette.info);     // Blue
Container(color: AppColorPalette.primary);  // Purple

// Priority colors
Container(color: AppColorPalette.priorityLow);     // Purple
Container(color: AppColorPalette.priorityMedium);  // Orange
Container(color: AppColorPalette.priorityHigh);    // Green
Container(color: AppColorPalette.priorityUrgent);  // Red
```

### Neutral Colors

```dart
// Basic neutrals
Container(color: AppColorPalette.white);
Container(color: AppColorPalette.black);
Container(color: AppColorPalette.grey);

// Grey shades (50-900)
Container(color: AppColorPalette.grey50);   // Lightest
Container(color: AppColorPalette.grey100);
Container(color: AppColorPalette.grey200);
Container(color: AppColorPalette.grey300);
Container(color: AppColorPalette.grey400);
Container(color: AppColorPalette.grey500);  // Base grey
Container(color: AppColorPalette.grey600);
Container(color: AppColorPalette.grey700);
Container(color: AppColorPalette.grey800);
Container(color: AppColorPalette.grey900);  // Darkest
```

### Dynamic Color Selection

Get colors by index (useful for lists or sets):

```dart
// Get color by index (0-4)
Color color = AppColorPalette.getColorByIndex(0); // Color 1 (purple)
Color color = AppColorPalette.getColorByIndex(1); // Color 2 (blue)

// Get color by position (1-5)
Color color = AppColorPalette.getColorByPosition(1); // Color 1 (purple)
Color color = AppColorPalette.getColorByPosition(2); // Color 2 (blue)

// Get all colors as a list
List<Color> colors = AppColorPalette.allColors;
```

### MaterialColor Conversion

For theme configuration that requires MaterialColor:

```dart
MaterialApp(
  theme: ThemeData(
    primarySwatch: AppColorPalette.materialColor1, // Purple
  ),
);
```

### Color Utilities

```dart
// Convert color to hex string (for storage)
String hex = AppColorPalette.colorToHex(AppColorPalette.color1);
// Result: "#9C27B0"

// Parse hex string to color (from storage)
Color? color = AppColorPalette.hexToColor("#9C27B0");

// Add opacity
Color transparentColor = AppColorPalette.withOpacity(AppColorPalette.color1, 0.5);

// Add alpha
Color alphaColor = AppColorPalette.withAlpha(AppColorPalette.color1, 128);
```

## Changing the Palette

To change the app's color scheme, modify the values in `lib/constants/color_palette.dart`:

### Option 1: Modify Individual Colors

```dart
class AppColorPalette {
  // Change individual color values
  static const Color color1 = Color(0xFFE91E63); // Changed to pink
  static const Color color2 = Color(0xFF00BCD4); // Changed to cyan
  // ... etc
}
```

### Option 2: Use Alternative Palettes

The file includes pre-defined alternative palettes. To switch, replace the color values in `AppColorPalette` with values from an alternative:

```dart
// Copy values from WarmPalette, CoolPalette, EarthPalette, PastelPalette, or VibrantPalette
// Example: Switch to Warm Palette
class AppColorPalette {
  static const Color color1 = Color(0xFFE91E63); // From WarmPalette.color1
  static const Color color2 = Color(0xFFFF5722); // From WarmPalette.color2
  // ... etc
}
```

### Available Alternative Palettes

1. **WarmPalette** - Pink, Deep Orange, Yellow, Orange, Red
2. **CoolPalette** - Indigo, Blue, Cyan, Teal, Green
3. **EarthPalette** - Brown, Light Brown, Olive Green, Orange, Dark Red
4. **PastelPalette** - Light Purple, Light Blue, Light Green, Light Orange, Light Red
5. **VibrantPalette** - Purple, Cyan, Light Green, Yellow, Deep Orange

### Option 3: Create Custom Palette

Add your own custom palette:

```dart
/// My custom palette
class MyCustomPalette {
  static const Color color1 = Color(0xFF...);
  static const Color color2 = Color(0xFF...);
  static const Color color3 = Color(0xFF...);
  static const Color color4 = Color(0xFF...);
  static const Color color5 = Color(0xFF...);
}

// Then update AppColorPalette to use your custom colors
```

## Files Refactored

The following files have been refactored to use the centralized palette:

### Core Files
- `lib/constants/color_palette.dart` - Palette definition
- `lib/constants/pomodoro_constants.dart` - Updated with palette references
- `lib/main.dart` - Theme color mapping

### Screens
- `lib/screens/workout_screen.dart`

### Common Widgets
- `lib/widgets/common/button_components.dart`
- `lib/widgets/common/card_components.dart`
- `lib/widgets/common/dialog_components.dart`
- `lib/widgets/common/state_components.dart`

## Rules

1. **NEVER** use `Colors.*` directly (except `Colors.transparent` when needed)
2. **ALWAYS** import and use `AppColorPalette` for colors
3. **USE** semantic names (success, error, warning) when the color represents a state
4. **USE** numbered colors (color1-5) or indexed access for decorative/organizational colors
5. **TEST** all changes by running `flutter test` to ensure no regressions

## Benefits

- **Consistency**: All colors come from one source
- **Easy Theming**: Change the entire app's colors by modifying one file
- **Maintainability**: No need to search and replace colors throughout the codebase
- **Accessibility**: Easy to test different color schemes for accessibility
- **Documentation**: Clear semantic meaning for each color usage

## Migration Status

### Completed
- Core system and constants
- Main app configuration
- Common widgets (buttons, cards, dialogs, state components)
- Workout screens

### Remaining
The following files still contain hardcoded colors and should be migrated when modified:
- Audio widgets (player, recorder, enhanced versions)
- Pomodoro widgets (timer, session squares, camera button, music widget, etc.)
- Various screens (analytics, motivational cards, exercises, etc.)

When working on these files, remember to:
1. Import `color_palette.dart`
2. Replace all `Colors.*` with `AppColorPalette.*`
3. Run tests to verify functionality


# Palette System Guide

## Overview

The application now uses a centralized palette system where **all colors come from the active palette stored in user settings**. No colors are hardcoded - everything is dynamically pulled from the selected palette.

## How It Works

### 1. Palette Selection
- Users can select from 3 palettes in Settings → Appearance:
  - **Grayscale**: 5 shades of grey
  - **Creative**: Vibrant colors (Purple, Blue, Green, Orange, Red)
  - **Pastel**: Soft, muted colors

### 2. Palette Storage
- Selected palette is stored in `UserSettingsModel.colorPalette`
- Saved to Hive database and persists across app restarts
- Default palette: `'creative'`

### 3. Dynamic Color System
- All colors in `AppColorPalette` are **getters** that pull from the active palette
- No hardcoded `Color(0xFF...)` values in `AppColorPalette`
- Colors automatically update when palette changes

### 4. App-Wide Updates
- When palette changes in settings, `PaletteNotifier` triggers a rebuild
- `MaterialApp` theme uses palette colors for:
  - Primary color
  - Accent color
  - Background colors
  - Text colors
  - Error/success/warning colors

## Using Colors in Your Code

### ✅ DO: Use AppColorPalette
```dart
import 'package:solo_level_system/constants/color_palette.dart';

// Primary colors (from active palette)
Container(color: AppColorPalette.color1);
Container(color: AppColorPalette.color2);
Container(color: AppColorPalette.color3);
Container(color: AppColorPalette.color4);
Container(color: AppColorPalette.color5);

// Semantic colors (from active palette)
Container(color: AppColorPalette.primary);
Container(color: AppColorPalette.accent);
Container(color: AppColorPalette.background);
Text('Hello', style: TextStyle(color: AppColorPalette.textColor));

// State colors (mapped from palette)
Container(color: AppColorPalette.success);  // Uses color3
Container(color: AppColorPalette.error);    // Uses color5
Container(color: AppColorPalette.warning);  // Uses color4
Container(color: AppColorPalette.info);     // Uses color2

// Grey shades (from active palette)
Container(color: AppColorPalette.grey50);
Container(color: AppColorPalette.grey100);
// ... through grey900
```

### ❌ DON'T: Use Hardcoded Colors
```dart
// ❌ BAD - Hardcoded colors
Container(color: Color(0xFF9C27B0));
Container(color: Colors.purple);
Container(color: Colors.blue);

// ✅ GOOD - Use palette
Container(color: AppColorPalette.primary);
Container(color: AppColorPalette.color2);
```

## Palette Structure

Each palette defines:
- **5 Primary Colors** (`color1` through `color5`)
- **Semantic Colors**:
  - `primary`: Main brand color
  - `accent`: Secondary highlight color
  - `background`: Main background color
  - `textColor`: Primary text color
- **Grey Shades** (`grey50` through `grey900`)

## Ensuring All Colors Use the Palette

### Automatic Enforcement
1. **Theme Colors**: `MaterialApp` theme automatically uses palette colors
2. **Palette Getters**: All `AppColorPalette` colors are getters (not constants)
3. **Settings Integration**: Palette is loaded on app startup and when settings change

### Manual Checks
To ensure your code uses the palette:

1. **Search for hardcoded colors**:
   ```bash
   # Look for Color(0x patterns
   grep -r "Color(0x" lib/
   ```

2. **Replace Colors.* with AppColorPalette**:
   - `Colors.red` → `AppColorPalette.error`
   - `Colors.green` → `AppColorPalette.success`
   - `Colors.blue` → `AppColorPalette.info`
   - `Colors.purple` → `AppColorPalette.primary`
   - `Colors.grey[300]` → `AppColorPalette.grey300`

3. **Use semantic names when possible**:
   - Instead of `AppColorPalette.color5` for errors, use `AppColorPalette.error`
   - Instead of `AppColorPalette.color3` for success, use `AppColorPalette.success`

## Palette Change Flow

1. User selects palette in Settings → Appearance
2. `PaletteSelectorWidget.onPaletteSelected()` is called
3. `AppColorPalette.setActivePalette()` updates the active palette
4. Settings are saved to Hive
5. `PaletteNotifier.notifyPaletteChanged()` triggers listeners
6. `_MyAppState` rebuilds with new palette colors
7. All UI elements automatically use new colors

## Files Modified

- `lib/constants/color_palette.dart` - All colors are now getters from active palette
- `lib/main.dart` - Theme uses palette colors, listens to palette changes
- `lib/screens/settings_screen.dart` - Palette selector with change notification
- `lib/utils/palette_notifier.dart` - Notifier for palette changes
- `lib/models/user_settings_model.dart` - Stores selected palette

## Best Practices

1. **Always use `AppColorPalette`** - Never hardcode colors
2. **Use semantic names** - `primary`, `accent`, `success`, `error` instead of `color1`, `color5`
3. **Test palette switching** - Verify your UI looks good with all 3 palettes
4. **Consider contrast** - Some palettes (like grayscale) may need special handling for readability

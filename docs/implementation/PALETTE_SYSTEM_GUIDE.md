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

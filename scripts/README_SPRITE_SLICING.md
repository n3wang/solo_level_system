# Workout Sprite Slicing

This directory contains scripts to pre-slice the workout icon sprite sheet into individual images.

## Why Pre-Slice?

Runtime sprite slicing on mobile devices can cause performance issues and visual artifacts. Pre-slicing the sprite sheet ensures:
- Better performance on mobile devices
- Consistent image quality
- Faster image loading
- No runtime processing overhead

## Usage

### Step 1: Install Dependencies

```bash
flutter pub get
```

### Step 2: Slice the Sprite Sheet

**On Windows:**
```bash
scripts\slice_sprites.bat
```

**On macOS/Linux:**
```bash
dart run scripts/slice_workout_sprites.dart
```

This will:
- Read `assets/images/icon/workout_icons_128px.png`
- Slice it into individual 128x128px PNG files
- Save them to `assets/images/icon/workout_icons_sliced/workout_icon_0.png`, `workout_icon_1.png`, etc.

### Step 3: Update Assets (if needed)

The `pubspec.yaml` already includes the sliced images directory. After slicing, run:

```bash
flutter pub get
```

### Step 4: Build and Run

The app will now automatically use pre-sliced images instead of runtime slicing. The code falls back to runtime slicing if pre-sliced images are not found (for backward compatibility).

## When to Re-slice

Re-slice the sprite sheet when:
- The original sprite sheet (`workout_icons_128px.png`) is updated
- New icons are added to the sprite sheet
- Before building for mobile deployment

## Integration with Build Process

You can integrate this into your build process:

1. **Before building for mobile:**
   ```bash
   scripts\slice_sprites.bat
   flutter build apk
   # or
   flutter build ios
   ```

2. **For development:**
   - Pre-sliced images are optional during development
   - The app will fall back to runtime slicing if pre-sliced images are missing
   - For best mobile performance, always use pre-sliced images

## File Structure

```
assets/images/icon/
├── workout_icons_128px.png          # Original sprite sheet
├── workout_icons_128px.csv           # Icon names mapping
└── workout_icons_sliced/             # Pre-sliced images (generated)
    ├── workout_icon_0.png
    ├── workout_icon_1.png
    └── ...
```

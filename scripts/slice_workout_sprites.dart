// scripts/slice_workout_sprites.dart
// Script to pre-slice workout icon sprite sheet into individual images
// Run this with: dart run scripts/slice_workout_sprites.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  await WorkoutSpriteSlicer().sliceSprites();
}

class WorkoutSpriteSlicer {
  static const int spriteSize = 128;
  static const String spriteSheetPath = 'assets/icon/workout_icons_128px.png';
  static const String outputDir = 'assets/icon/workout_icons_sliced';

  Future<void> sliceSprites() async {
    print('Starting sprite sheet slicing...');

    // Check if sprite sheet exists
    final spriteSheetFile = File(spriteSheetPath);
    if (!spriteSheetFile.existsSync()) {
      print('Error: Sprite sheet not found at $spriteSheetPath');
      return;
    }

    // Read the sprite sheet
    print('Reading sprite sheet...');
    final spriteSheetBytes = await spriteSheetFile.readAsBytes();
    final spriteSheet = img.decodeImage(spriteSheetBytes);

    if (spriteSheet == null) {
      print('Error: Failed to decode sprite sheet image');
      return;
    }

    print('Sprite sheet dimensions: ${spriteSheet.width}x${spriteSheet.height}');

    // Calculate number of sprites
    final spriteCount = (spriteSheet.width / spriteSize).floor();
    print('Found $spriteCount sprites in the sheet');

    // Create output directory
    final outputDirectory = Directory(outputDir);
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
      print('Created output directory: $outputDir');
    } else {
      // Clear existing files
      print('Clearing existing sliced images...');
      outputDirectory.listSync().forEach((entity) {
        if (entity is File && entity.path.endsWith('.png')) {
          entity.deleteSync();
        }
      });
    }

    // Slice each sprite
    print('Slicing sprites...');
    int successCount = 0;
    for (int i = 0; i < spriteCount; i++) {
      try {
        final x = i * spriteSize;
        
        // Extract the sprite region
        final sprite = img.copyCrop(
          spriteSheet,
          x: x,
          y: 0,
          width: spriteSize,
          height: spriteSize,
        );

        // Save as PNG
        final outputPath = '$outputDir/workout_icon_$i.png';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(img.encodePng(sprite));

        successCount++;
        if ((i + 1) % 5 == 0 || i == spriteCount - 1) {
          print('  Sliced ${i + 1}/$spriteCount sprites...');
        }
      } catch (e) {
        print('Error slicing sprite $i: $e');
      }
    }

    print('\n✓ Successfully sliced $successCount/$spriteCount sprites');
    print('Output directory: $outputDir');
    print('\nNext steps:');
    print('1. Update pubspec.yaml to include: assets/icon/workout_icons_sliced/');
    print('2. Run: flutter pub get');
    print('3. The app will now use pre-sliced images instead of runtime slicing');
  }
}

// scripts/slice_workout_sprites.dart
// Script to pre-slice workout icon sprite sheet into individual images with slug names
// Run this with: dart run scripts/slice_workout_sprites.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  await WorkoutSpriteSlicer().sliceSprites();
}

class WorkoutSpriteSlicer {
  static const int spriteSize = 128;
  static const String spriteSheetPath = 'assets/icon/workout_icons_128px.png';
  static const String csvPath = 'assets/icon/workout_icons_128px.csv';
  static const String outputDir = 'assets/icon/workout_icons_sliced';

  /// Convert exercise name to slug (lowercase, underscores, no special chars)
  String nameToSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9_\s]'), '') // Keep underscores
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
        .replaceAll(RegExp(r'_+'), '_') // Collapse multiple underscores
        .replaceAll(RegExp(r'^_|_$'), ''); // Remove leading/trailing underscores
  }

  /// Read exercise names from CSV file
  Future<List<String>> readExerciseNamesFromCsv() async {
    final csvFile = File(csvPath);
    if (!csvFile.existsSync()) {
      print('Warning: CSV file not found at $csvPath');
      return [];
    }

    final lines = await csvFile.readAsLines();
    final exerciseNames = <String>[];

    // Skip header row, read exercise names
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Parse CSV - first column is exercise name
      String exerciseName;
      if (line.startsWith('"')) {
        // Handle quoted values
        final endQuote = line.indexOf('"', 1);
        exerciseName = line.substring(1, endQuote);
      } else {
        exerciseName = line.split(',')[0];
      }

      exerciseName = exerciseName.trim();
      if (exerciseName.isNotEmpty) {
        exerciseNames.add(exerciseName);
      }
    }

    return exerciseNames;
  }

  Future<void> sliceSprites() async {
    print('Starting sprite sheet slicing with slug names...');

    // Check if sprite sheet exists
    final spriteSheetFile = File(spriteSheetPath);
    if (!spriteSheetFile.existsSync()) {
      print('Error: Sprite sheet not found at $spriteSheetPath');
      return;
    }

    // Read exercise names from CSV
    print('Reading exercise names from CSV...');
    final exerciseNames = await readExerciseNamesFromCsv();
    print('Found ${exerciseNames.length} exercise names in CSV');

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
    final slugMapping = <int, String>{}; // index -> slug name

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

        // Determine filename - use slug from CSV or fallback to index
        String filename;
        if (i < exerciseNames.length) {
          final slug = nameToSlug(exerciseNames[i]);
          filename = '$slug.png';
          slugMapping[i] = slug;
          print('  [$i] "${exerciseNames[i]}" -> $slug.png');
        } else {
          filename = 'workout_icon_$i.png';
          slugMapping[i] = 'workout_icon_$i';
          print('  [$i] (no CSV entry) -> $filename');
        }

        // Save as PNG
        final outputPath = '$outputDir/$filename';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(img.encodePng(sprite));

        successCount++;
      } catch (e) {
        print('Error slicing sprite $i: $e');
      }
    }

    print('\n${'=' * 60}');
    print('SLUG MAPPING (for YAML icon field):');
    print('=' * 60);
    slugMapping.forEach((index, slug) {
      final name = index < exerciseNames.length ? exerciseNames[index] : '(unknown)';
      print('  $index: $name -> icon: "$slug"');
    });

    print('\n${'=' * 60}');
    print('Successfully sliced $successCount/$spriteCount sprites');
    print('Output directory: $outputDir');
    print('\nNext steps:');
    print('1. Update default_workouts.yaml to use icon: "slug_name" instead of sprite_index');
    print('2. Run: flutter pub get');
    print('3. The app will now use slug-named icon files');
  }
}

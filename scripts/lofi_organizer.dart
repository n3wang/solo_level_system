import 'dart:io';
import 'dart:convert';

void main() async {
  await LofiOrganizer().organize();
}

class LofiOrganizer {
  static const String lofiDir = 'assets/lofi';
  static const String mappingFile = 'assets/lofi/lofi_mapping.json';

  Future<void> organize() async {
    print('Starting lofi organization...');

    final directory = Directory(lofiDir);
    if (!directory.existsSync()) {
      print('Error: $lofiDir directory not found');
      return;
    }

    final files = directory.listSync()
        .where((entity) => entity is File && entity.path.endsWith('.mp3'))
        .cast<File>()
        .toList();

    final List<Map<String, dynamic>> lofiMappings = [];
    int counter = 1;

    for (final file in files) {
      final fileName = file.uri.pathSegments.last;
      final originalName = fileName.replaceAll('.mp3', '');
      final newName = 'lofi_${counter.toString().padLeft(3, '0')}.mp3';
      final newPath = '${directory.path}${Platform.pathSeparator}$newName';

      // Skip if already renamed with lofi_ prefix and 3 digits
      if (RegExp(r'^lofi_\d{3}$').hasMatch(originalName)) {
        print('Skipping already renamed file: $fileName');

        // Still add to mapping for existing renamed files
        final stats = file.statSync();
        final fileSizeKB = stats.size / 1024;
        final estimatedDuration = _estimateDuration(fileSizeKB);

        lofiMappings.add({
          'id': counter,
          'filename': fileName,
          'originalName': originalName,
          'title': 'Lofi Track ${counter.toString().padLeft(3, '0')}',
          'author': 'Unknown Artist',
          'site': 'Freesound/Pixabay',
          'duration': estimatedDuration,
          'fileSize': fileSizeKB.round(),
        });

        counter++;
        continue;
      }

      // Skip special files (sound effects)
      if (originalName.startsWith('s0')) {
        print('Skipping sound effect file: $fileName');
        continue;
      }

      try {
        // Get file stats for duration estimation
        final stats = file.statSync();
        final fileSizeKB = stats.size / 1024;
        final estimatedDuration = _estimateDuration(fileSizeKB);

        // Extract metadata from filename
        final metadata = _extractMetadata(originalName);

        // Add to mapping
        lofiMappings.add({
          'id': counter,
          'filename': newName,
          'originalName': originalName,
          'title': metadata['title'],
          'author': metadata['author'],
          'site': metadata['site'],
          'duration': estimatedDuration,
          'fileSize': fileSizeKB.round(),
        });

        // Rename file
        final newFile = file.renameSync(newPath);
        print('Renamed: ${file.path} -> ${newFile.path}');

        counter++;
      } catch (e) {
        print('Error processing ${file.path}: $e');
      }
    }

    // Save mapping to JSON
    await _saveMappingToJson(lofiMappings);
    print('Organization complete! Generated ${lofiMappings.length} mappings.');
  }

  Map<String, String> _extractMetadata(String filename) {
    // Clean filename and extract potential metadata
    final cleanName = filename
        .replaceAll(RegExp(r'^\d+-'), '') // Remove leading numbers
        .replaceAll(RegExp(r'-\d+$'), '') // Remove trailing numbers
        .replaceAll('x27', "'") // Replace encoded apostrophe
        .replaceAll('-', ' ')
        .trim();

    // Basic title formatting
    final title = cleanName
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');

    return {
      'title': title.isNotEmpty ? title : 'Unknown Track',
      'author': 'Unknown Artist',
      'site': 'Freesound/Pixabay', // Common sources for free audio
    };
  }

  String _estimateDuration(double fileSizeKB) {
    // Rough estimation: 128kbps MP3 = ~1MB per minute
    final minutes = (fileSizeKB / 1024).round();
    final seconds = ((fileSizeKB % 1024) / 17).round(); // Rough conversion

    if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _saveMappingToJson(List<Map<String, dynamic>> mappings) async {
    final jsonData = {
      'version': '1.0',
      'generated': DateTime.now().toIso8601String(),
      'total_tracks': mappings.length,
      'tracks': mappings,
    };

    final file = File(mappingFile);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );

    print('Saved mapping to: $mappingFile');
  }
}


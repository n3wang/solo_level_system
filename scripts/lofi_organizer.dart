import 'dart:io';
import 'dart:convert';

void main() async {
  await LofiOrganizer().organize();
}

class LofiOrganizer {
  static const String lofiDir = 'assets/audio/lofi';
  static const String mappingFile = 'assets/data/lofi_mapping.json';

  Future<void> organize() async {
    print('Starting lofi organization...');

    final directory = Directory(lofiDir);
    if (!directory.existsSync()) {
      print('Error: $lofiDir directory not found');
      return;
    }

    final files = directory
        .listSync()
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
          'albumImage': _getAlbumImage(
            'Lofi Track ${counter.toString().padLeft(3, '0')}',
            counter,
          ),
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
          'albumImage': _getAlbumImage(metadata['title']!, counter),
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
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
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
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
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

  String _getAlbumImage(String title, int counter) {
    final titleLower = title.toLowerCase();

    // Theme-based album image selection
    if (titleLower.contains('80') ||
        titleLower.contains('retro') ||
        titleLower.contains('neon')) {
      return 'album/al09-80s.png';
    }
    if (titleLower.contains('study') ||
        titleLower.contains('lofi') && counter < 10) {
      return 'album/al02-lofistudybook.png';
    }
    if (titleLower.contains('sport') ||
        titleLower.contains('gym') ||
        titleLower.contains('fitness')) {
      return 'album/al11-sports.png';
    }
    if (titleLower.contains('space') ||
        titleLower.contains('interstellar') ||
        titleLower.contains('voyager')) {
      return 'album/al05-spaceexploration.png';
    }
    if (titleLower.contains('science') ||
        titleLower.contains('electronic') ||
        titleLower.contains('tech')) {
      return 'album/al08-electronics.png';
    }
    if (titleLower.contains('dark') ||
        titleLower.contains('melancholy') ||
        titleLower.contains('haunted')) {
      return 'album/al06-haunted.png';
    }
    if (titleLower.contains('ghibli') || titleLower.contains('wind')) {
      return 'album/al16-wind.png';
    }
    if (titleLower.contains('happy') ||
        titleLower.contains('peaceful') ||
        titleLower.contains('calm')) {
      return 'album/al15-happyplace.png';
    }
    if (titleLower.contains('detective') ||
        titleLower.contains('stranger') ||
        titleLower.contains('paranormal')) {
      return 'album/al05-paranormal.png';
    }
    if (titleLower.contains('hero') || titleLower.contains('willsmith')) {
      return 'album/al10-willsmith.png';
    }
    if (titleLower.contains('fashion') ||
        titleLower.contains('commercial') ||
        titleLower.contains('balenciaga')) {
      return 'album/al13-commercial.png';
    }
    if (titleLower.contains('chaos') || titleLower.contains('shattered')) {
      return 'album/al16-chaos.png';
    }

    // Default fallback based on ID ranges
    if (counter <= 10) return 'album/al1-lofigirl.png';
    if (counter <= 20) return 'album/al02-lofistudybook.png';
    if (counter <= 30) return 'album/al15-happyplace.png';
    return 'album/al14-album.png';
  }
}

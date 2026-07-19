import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/lofi_track.dart';

class LofiService {
  static const String _mappingPath = 'assets/data/lofi_tracks.yml';

  /// Bundled looping covers (PNG refs in the mapping can be absent from the repo).
  static const List<String> _bundledGifCovers = [
    'album/lab_1.gif',
    'album/lab_2.gif',
    'album/lab_3.gif',
    'album/lab_4.gif',
    'album/ghost_lofi_1.gif',
    'album/ghost_lofi_2.gif',
    'album/ghost_lofi_3.gif',
    'album/ghost_lofi_4.gif',
    'album/90s_jap_1.gif',
    'album/90s_jap_2.gif',
    'album/90s_jap_3.gif',
    'album/like_a_dog_1.gif',
    'album/like_a_dog_2.gif',
    'album/like_a_dog_3.gif',
    'album/like_a_dog_4.gif',
    'album/like_a_dog_5.gif',
    'album/like_a_dog_6.gif',
    'album/like_a_dog_7.gif',
  ];

  static const List<String> _knownExtraTrackFilenames = [
    'like_a_dog_1.MP3',
    'like_a_dog_2.MP3',
    'like_a_dog_3.MP3',
    'like_a_dog_4.MP3',
    'like_a_dog_5.MP3',
    'like_a_dog_6.MP3',
    'ghost_lofi_1.MP3',
    'ghost_lofi_2.MP3',
    'ghost_lofi_3.MP3',
    'ghost_lofi_4.MP3',
    'ghost_lofi_7.MP3',
    'ghost_lofi_8.MP3',
    'lab_1.MP3',
    'lab_2.MP3',
    'lab_3.MP3',
    'lab_4.MP3',
    'lab_5.MP3',
    '90s_jap_3.MP3',
    '90s_jap_4.MP3',
    '90s_jap_5.MP3',
    '90s_jap_6.MP3',
    'kiraisuki.MP3',
  ];
  static LofiMapping? _cachedMapping;

  static Future<LofiMapping> getLofiMapping() async {
    if (_cachedMapping != null) {
      return _cachedMapping!;
    }

    try {
      final yamlData = loadYaml(await rootBundle.loadString(_mappingPath));
      final base = LofiMapping.fromJson(_stringKeyedMap(yamlData));
      final mergedTracks = _mergeWithKnownExtraTracks(
        base.tracks.map(_withGifAlbumArt).toList(growable: false),
      );
      final normalized = mergedTracks
          .map(_withGifAlbumArt)
          .toList(growable: false);
      _cachedMapping = LofiMapping(
        version: base.version,
        generated: base.generated,
        totalTracks: normalized.length,
        tracks: normalized,
      );
      return _cachedMapping!;
    } catch (e) {
      throw Exception('Failed to load lofi mapping: $e');
    }
  }

  static Future<List<LofiTrack>> getAllTracks() async {
    final mapping = await getLofiMapping();
    return mapping.tracks;
  }

  static Future<LofiTrack?> getTrackById(int id) async {
    final mapping = await getLofiMapping();
    try {
      return mapping.tracks.firstWhere((track) => track.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<LofiTrack> getRandomTrack() async {
    final tracks = await getAllTracks();
    if (tracks.isEmpty) {
      throw Exception('No lofi tracks available');
    }
    tracks.shuffle();
    return tracks.first;
  }

  static Future<List<LofiTrack>> getTracksByDurationRange({
    Duration? minDuration,
    Duration? maxDuration,
  }) async {
    final tracks = await getAllTracks();

    return tracks.where((track) {
      final duration = _parseDuration(track.duration);
      if (minDuration != null && duration < minDuration) return false;
      if (maxDuration != null && duration > maxDuration) return false;
      return true;
    }).toList();
  }

  static Duration _parseDuration(String durationString) {
    final parts = durationString.split(':');
    if (parts.length != 2) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;

    return Duration(minutes: minutes, seconds: seconds);
  }

  static Map<String, dynamic> _stringKeyedMap(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Lofi mapping root must be a map');
    }
    return value.map(
      (key, item) => MapEntry(key.toString(), _plainYamlValue(item)),
    );
  }

  static dynamic _plainYamlValue(dynamic value) {
    if (value is Map) return _stringKeyedMap(value);
    if (value is List) return value.map(_plainYamlValue).toList();
    return value;
  }

  /// Forces a non-null `.gif` cover so UI always resolves [LofiTrack.albumImagePath].
  static LofiTrack _withGifAlbumArt(LofiTrack track) {
    final trimmed = track.albumImage?.trim() ?? '';
    if (trimmed.toLowerCase().endsWith('.gif')) {
      return track;
    }
    final bucket = trimmed.isEmpty ? 0 : trimmed.hashCode;
    final idx =
        ((track.id * 47 + bucket + track.filename.hashCode).abs()) %
        _bundledGifCovers.length;
    final path = _bundledGifCovers[idx];
    return track.copyWith(albumImage: path);
  }

  static List<LofiTrack> _mergeWithKnownExtraTracks(
    List<LofiTrack> baseTracks,
  ) {
    final existingByFilename = <String>{
      for (final t in baseTracks) t.filename.toLowerCase(),
    };
    final maxId = baseTracks.fold<int>(0, (max, t) => t.id > max ? t.id : max);
    if (_knownExtraTrackFilenames.isEmpty) return baseTracks;

    var nextId = maxId + 1;
    final additions = <LofiTrack>[];
    for (final filename in _knownExtraTrackFilenames) {
      final lower = filename.toLowerCase();
      if (existingByFilename.contains(lower)) continue;
      final originalName = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
      additions.add(
        LofiTrack(
          id: nextId++,
          filename: filename,
          originalName: originalName,
          title: _prettyTitleFromName(originalName),
          author: 'Unknown Artist',
          site: 'Open-license/user-imported',
          duration: '0:00',
          fileSize: 0,
          albumImage: _defaultAlbumImageForFilename(lower),
        ),
      );
    }

    if (additions.isEmpty) return baseTracks;
    final merged = [...baseTracks, ...additions];
    merged.sort((a, b) => a.id.compareTo(b.id));
    return merged;
  }

  static String _prettyTitleFromName(String raw) {
    final normalized = raw.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return raw;
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  static String? _defaultAlbumImageForFilename(String filenameLower) {
    int? trailingIndex() {
      final m = RegExp(r'_(\d+)\.[^.]+$').firstMatch(filenameLower);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    }

    if (filenameLower.startsWith('kiraisuki')) {
      return 'album/90s_jap_2.gif';
    }
    if (filenameLower.startsWith('like_a_dog_')) {
      final n = trailingIndex() ?? 1;
      return 'album/like_a_dog_${n.clamp(1, 7)}.gif';
    }
    if (filenameLower.startsWith('ghost_lofi_')) {
      final n = trailingIndex() ?? 1;
      final slot = ((n - 1) % 4) + 1;
      return 'album/ghost_lofi_$slot.gif';
    }
    if (filenameLower.startsWith('lab_')) {
      final n = trailingIndex() ?? 1;
      return 'album/lab_${n.clamp(1, 4)}.gif';
    }
    if (filenameLower.startsWith('90s_jap_')) {
      final n = trailingIndex() ?? 1;
      final slot = ((n - 1) % 3) + 1;
      return 'album/90s_jap_$slot.gif';
    }
    return null;
  }

  static void clearCache() {
    _cachedMapping = null;
  }
}

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/lofi_track.dart';

class LofiService {
  static const String _mappingPath = 'assets/lofi/lofi_mapping.json';
  static LofiMapping? _cachedMapping;

  static Future<LofiMapping> getLofiMapping() async {
    if (_cachedMapping != null) {
      return _cachedMapping!;
    }

    try {
      final String jsonString = await rootBundle.loadString(_mappingPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _cachedMapping = LofiMapping.fromJson(jsonData);
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

  static void clearCache() {
    _cachedMapping = null;
  }
}
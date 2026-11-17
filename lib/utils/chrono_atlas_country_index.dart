import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:solo_level_system/utils/chrono_atlas_map_config.dart';

/// Country name lookup from [ChronoAtlasMapConfig.shapeAsset] (point-in-polygon).
class ChronoAtlasCountryIndex {
  ChronoAtlasCountryIndex._(this._countries);

  final List<_CountryPoly> _countries;

  static ChronoAtlasCountryIndex? _instance;
  static Future<ChronoAtlasCountryIndex>? _loading;

  static Future<ChronoAtlasCountryIndex> load() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= _load().then((index) {
      _instance = index;
      _loading = null;
      return index;
    });
  }

  static Future<ChronoAtlasCountryIndex> _load() async {
    final raw = await rootBundle.loadString(ChronoAtlasMapConfig.shapeAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];
    final countries = <_CountryPoly>[];

    for (final feature in features) {
      if (feature is! Map) continue;
      final props = feature['properties'];
      final geometry = feature['geometry'];
      if (props is! Map || geometry is! Map) continue;
      final name = props[ChronoAtlasMapConfig.shapeDataField]?.toString();
      if (name == null || name.isEmpty) continue;
      final type = geometry['type']?.toString();
      final coords = geometry['coordinates'];
      if (coords is! List) continue;

      final rings = <List<List<double>>>[];
      if (type == 'Polygon') {
        _collectOuterRings(coords, rings);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          if (poly is List) _collectOuterRings(poly, rings);
        }
      }
      if (rings.isEmpty) continue;
      countries.add(_CountryPoly(name: name, rings: rings));
    }

    return ChronoAtlasCountryIndex._(countries);
  }

  /// GeoJSON polygons: first ring is exterior; ignore holes for hit-testing.
  static void _collectOuterRings(
    List<dynamic> polygon,
    List<List<List<double>>> out,
  ) {
    if (polygon.isEmpty) return;
    final outer = polygon.first;
    if (outer is! List || outer.length < 3) return;
    final ring = <List<double>>[];
    for (final point in outer) {
      if (point is! List || point.length < 2) continue;
      final lng = (point[0] as num?)?.toDouble();
      final lat = (point[1] as num?)?.toDouble();
      if (lng == null || lat == null) continue;
      ring.add([lng, lat]);
    }
    if (ring.length >= 3) out.add(ring);
  }

  /// Returns the country [NAME] containing [lat]/[lng], or null (ocean / gap).
  String? countryAt({required double lat, required double lng}) {
    for (final country in _countries) {
      if (country.contains(lat: lat, lng: lng)) return country.name;
    }
    return null;
  }
}

class _CountryPoly {
  const _CountryPoly({required this.name, required this.rings});

  final String name;
  final List<List<List<double>>> rings;

  bool contains({required double lat, required double lng}) {
    for (final ring in rings) {
      if (_pointInRing(lng: lng, lat: lat, ring: ring)) return true;
    }
    return false;
  }

  /// Ray casting; [ring] points are `[lng, lat]`.
  static bool _pointInRing({
    required double lng,
    required double lat,
    required List<List<double>> ring,
  }) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i][0];
      final yi = ring[i][1];
      final xj = ring[j][0];
      final yj = ring[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng <
              (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

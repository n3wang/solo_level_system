import 'dart:math' as math;

class ChronoAtlasPin {
  const ChronoAtlasPin({
    required this.lat,
    required this.lng,
    this.radiusKm,
  });

  final double lat;
  final double lng;
  final double? radiusKm;
}

class ChronoAtlasGeoResult {
  const ChronoAtlasGeoResult({
    required this.distanceKm,
    required this.score,
    required this.nearestPin,
  });

  final double distanceKm;
  final int score;
  final ChronoAtlasPin nearestPin;
}

class ChronoAtlasYearResult {
  const ChronoAtlasYearResult({
    required this.deltaYears,
    required this.score,
  });

  final int deltaYears;
  final int score;
}

/// Haversine nearest-pin + year-error scoring for Chrono Atlas.
class ChronoAtlasScoring {
  ChronoAtlasScoring._();

  static const double _earthRadiusKm = 6371.0;

  static double haversineKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Effective distance after optional accept radius (0 if inside radius).
  static ChronoAtlasGeoResult scoreGeo({
    required double guessLat,
    required double guessLng,
    required List<ChronoAtlasPin> pins,
  }) {
    if (pins.isEmpty) {
      throw ArgumentError('pins must not be empty');
    }

    ChronoAtlasPin nearest = pins.first;
    var bestRaw = double.infinity;
    for (final pin in pins) {
      final km = haversineKm(
        lat1: guessLat,
        lng1: guessLng,
        lat2: pin.lat,
        lng2: pin.lng,
      );
      if (km < bestRaw) {
        bestRaw = km;
        nearest = pin;
      }
    }

    final radius = nearest.radiusKm ?? 0;
    final effective = bestRaw <= radius ? 0.0 : bestRaw - radius;
    return ChronoAtlasGeoResult(
      distanceKm: effective,
      score: _geoPoints(effective),
      nearestPin: nearest,
    );
  }

  static ChronoAtlasYearResult scoreYear({
    required int guess,
    required int answer,
  }) {
    final delta = (guess - answer).abs();
    return ChronoAtlasYearResult(deltaYears: delta, score: _yearPoints(delta));
  }

  static int _geoPoints(double km) {
    if (km <= 250) return 5000;
    if (km <= 750) return 3500;
    if (km <= 1500) return 2000;
    if (km <= 3000) return 1000;
    if (km >= 5000) return 0;
    return math.max(0, (500 - km / 20).round());
  }

  static int _yearPoints(int delta) {
    if (delta == 0) return 5000;
    if (delta <= 5) return 4000;
    if (delta <= 25) return 2500;
    if (delta <= 100) return 1000;
    return 0;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Parse `lat|lng` or `lat|lng|radiusKm` pins separated by `;`.
  static List<ChronoAtlasPin> parsePins(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final pins = <ChronoAtlasPin>[];
    for (final chunk in raw.split(';')) {
      final parts = chunk.trim().split('|');
      if (parts.length < 2) continue;
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) continue;
      final radius =
          parts.length >= 3 ? double.tryParse(parts[2].trim()) : null;
      pins.add(ChronoAtlasPin(lat: lat, lng: lng, radiusKm: radius));
    }
    return pins;
  }
}

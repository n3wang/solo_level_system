import 'package:flutter_test/flutter_test.dart';
import 'package:solo_level_system/utils/chrono_atlas_scoring.dart';

void main() {
  group('ChronoAtlasScoring', () {
    test('parsePins reads multi-pin lat|lng|radius', () {
      final pins = ChronoAtlasScoring.parsePins(
        '-18.9|47.5|500;-1.3|36.8|400',
      );
      expect(pins.length, 2);
      expect(pins[0].lat, closeTo(-18.9, 0.001));
      expect(pins[0].radiusKm, 500);
      expect(pins[1].lng, closeTo(36.8, 0.001));
    });

    test('scoreGeo uses nearest pin and radius', () {
      const pins = [
        ChronoAtlasPin(lat: 0, lng: 0, radiusKm: 100),
        ChronoAtlasPin(lat: 10, lng: 10, radiusKm: 50),
      ];
      final near = ChronoAtlasScoring.scoreGeo(
        guessLat: 0.1,
        guessLng: 0.1,
        pins: pins,
      );
      expect(near.nearestPin.lat, 0);
      expect(near.distanceKm, 0); // inside radius
      expect(near.score, 5000);
    });

    test('scoreYear bands', () {
      expect(ChronoAtlasScoring.scoreYear(guess: 2015, answer: 2015).score, 5000);
      expect(ChronoAtlasScoring.scoreYear(guess: 2010, answer: 2015).score, 4000);
      expect(ChronoAtlasScoring.scoreYear(guess: 2000, answer: 2015).score, 2500);
      expect(ChronoAtlasScoring.scoreYear(guess: 1900, answer: 2015).score, 0);
    });
  });
}

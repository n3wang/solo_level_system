import 'package:flutter_test/flutter_test.dart';
import 'package:solo_level_system/utils/collectible_deck_seed_service.dart';

void main() {
  group('parseDeckPageToken', () {
    test('plain page number has no rotation', () {
      final parsed = CollectibleDeckSeedService.parseDeckPageToken('257');
      expect(parsed.page, 257);
      expect(parsed.rotateDegrees, 0);
    });

    test('trailing r means rotate 90 degrees', () {
      final parsed = CollectibleDeckSeedService.parseDeckPageToken('258r');
      expect(parsed.page, 258);
      expect(parsed.rotateDegrees, 90);
    });

    test('uppercase R is accepted', () {
      final parsed = CollectibleDeckSeedService.parseDeckPageToken('259R');
      expect(parsed.page, 259);
      expect(parsed.rotateDegrees, 90);
    });

    test('empty token yields null page', () {
      final parsed = CollectibleDeckSeedService.parseDeckPageToken('  ');
      expect(parsed.page, isNull);
      expect(parsed.rotateDegrees, 0);
    });
  });
}

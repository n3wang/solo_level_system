import 'package:flutter_test/flutter_test.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

void main() {
  group('NamingConvention.parse', () {
    test('square tile', () {
      final r = NamingConvention.parse('icons_32px');
      expect(r?.name, 'icons');
      expect(r?.tileWidth, 32);
      expect(r?.tileHeight, 32);
      expect(r?.isSquare, true);
    });

    test('non-square tile', () {
      final r = NamingConvention.parse('characters_32x48px');
      expect(r?.name, 'characters');
      expect(r?.tileWidth, 32);
      expect(r?.tileHeight, 48);
      expect(r?.isSquare, false);
    });

    test('multi-word name', () {
      final r = NamingConvention.parse('workout_icons_128px');
      expect(r?.name, 'workout_icons');
      expect(r?.tileWidth, 128);
    });

    test('returns null for non-matching name', () {
      expect(NamingConvention.parse('spritesheet'), isNull);
      expect(NamingConvention.parse('icons64px'), isNull);
      expect(NamingConvention.parse('items'), isNull);
    });

    test('landscape tile', () {
      final r = NamingConvention.parse('banners_128x32px');
      expect(r?.tileWidth, 128);
      expect(r?.tileHeight, 32);
    });
  });

  group('NamingConvention.stemFrom', () {
    test('strips extension and directory', () {
      expect(NamingConvention.stemFrom('assets/icons_32px.png'), 'icons_32px');
      expect(NamingConvention.stemFrom('icons_32px.webp'), 'icons_32px');
    });
  });
}

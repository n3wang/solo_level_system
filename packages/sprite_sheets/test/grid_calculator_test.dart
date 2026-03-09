import 'package:flutter_test/flutter_test.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

void main() {
  group('GridCalculator.calculate', () {
    test('clean grid', () {
      final r = GridCalculator.calculate(
        imageWidth: 320,
        imageHeight: 160,
        tileWidth: 32,
        tileHeight: 32,
        sheetName: 'test',
      );
      expect(r.info.columns, 10);
      expect(r.info.rows, 5);
      expect(r.info.totalSlots, 50);
      expect(r.info.hasRemainder, false);
      expect(r.warnings, isEmpty);
    });

    test('remainder on x emits warning', () {
      final r = GridCalculator.calculate(
        imageWidth: 300,
        imageHeight: 160,
        tileWidth: 32,
        tileHeight: 32,
        sheetName: 'test',
      );
      expect(r.info.columns, 9);
      expect(r.info.remainderX, 12);
      expect(r.warnings, hasLength(1));
      expect(r.warnings.first, contains('12px remainder'));
    });

    test('image too small throws InvalidGridException', () {
      expect(
        () => GridCalculator.calculate(
          imageWidth: 20,
          imageHeight: 20,
          tileWidth: 32,
          tileHeight: 32,
          sheetName: 'tiny',
        ),
        throwsA(isA<InvalidGridException>()),
      );
    });

    test('non-square tiles', () {
      final r = GridCalculator.calculate(
        imageWidth: 128,
        imageHeight: 192,
        tileWidth: 32,
        tileHeight: 48,
        sheetName: 'chars',
      );
      expect(r.info.columns, 4);
      expect(r.info.rows, 4);
      expect(r.info.totalSlots, 16);
    });
  });
}

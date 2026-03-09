import 'package:flutter_test/flutter_test.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

void main() {
  group('CsvParser.parse', () {
    test('minimal (name only, sequential index)', () {
      const csv = 'name\nsword\nshield\npotion';
      final rows = CsvParser.parse(csv);
      expect(rows, hasLength(3));
      expect(rows[0].name, 'sword');
      expect(rows[0].number, isNull);
      expect(rows[2].name, 'potion');
    });

    test('explicit index column', () {
      const csv = 'name,number\nsword,0\nshield,5\npotion,12';
      final rows = CsvParser.parse(csv);
      expect(rows[0].number, 0);
      expect(rows[1].number, 5);
      expect(rows[2].number, 12);
    });

    test('extended metadata columns', () {
      const csv = 'name,number,tags,category\nsword,0,weapon;melee,equipment';
      final rows = CsvParser.parse(csv);
      expect(rows[0].metadata['tags'], 'weapon;melee');
      expect(rows[0].metadata['category'], 'equipment');
    });

    test('skips empty lines and comments', () {
      const csv = 'name\n# this is a comment\nsword\n\nshield';
      final rows = CsvParser.parse(csv);
      expect(rows, hasLength(2));
    });

    test('strips BOM', () {
      final csv = '\uFEFFname\nsword';
      final rows = CsvParser.parse(csv);
      expect(rows[0].name, 'sword');
    });

    test('no header → every line is a name', () {
      const csv = 'sword\nshield\npotion';
      final rows = CsvParser.parse(csv);
      expect(rows, hasLength(3));
      expect(rows[0].name, 'sword');
    });

    test('quoted fields with commas', () {
      const csv = 'name\n"sword, iron"';
      final rows = CsvParser.parse(csv);
      expect(rows[0].name, 'sword, iron');
    });
  });

  group('SpriteSheets.suggest (fuzzy match)', () {
    test('finds close match', () {
      final result = SpriteSheets.suggest('swrod', ['sword', 'shield', 'potion']);
      expect(result, 'sword');
    });

    test('returns null when no match within distance 2', () {
      final result = SpriteSheets.suggest('xyz', ['sword', 'shield']);
      expect(result, isNull);
    });
  });
}

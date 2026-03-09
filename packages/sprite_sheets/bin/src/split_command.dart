import 'dart:io';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'shared.dart';

/// `spritesheet split <image> [options]`
///
/// Physically slices a spritesheet into individual named files.
void runSplit(List<String> args) {
  final parser = ArgParser()
    ..addOption('tile',
        abbr: 't',
        help: 'Tile size: 32 (square) or 32x48 (non-square). '
            'Defaults to parsing from filename.')
    ..addOption('csv', abbr: 'c', help: 'Path to CSV manifest.')
    ..addOption('output',
        abbr: 'o', defaultsTo: './out', help: 'Output directory.')
    ..addOption('prefix', abbr: 'p', defaultsTo: '', help: 'Filename prefix.')
    ..addOption('format',
        abbr: 'f', defaultsTo: 'png', help: 'Output format: png or webp.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    stdout.writeln('Usage: spritesheet split <image> [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final imagePath = results.rest.first;
  final stem = p.basenameWithoutExtension(imagePath);
  final tile = parseTileSize(results['tile'] as String?, stem);

  if (tile == null) {
    stderr.writeln(
      'Error: cannot determine tile size.\n'
      '  Rename the file to match "{name}_{W}px.png" or use --tile 32.',
    );
    exit(1);
  }

  final source = decodeFile(imagePath);
  if (source == null) {
    stderr.writeln('Error: cannot decode "$imagePath".');
    exit(1);
  }

  final columns = source.width ~/ tile.w;
  final rows = source.height ~/ tile.h;
  final totalSlots = columns * rows;

  if (source.width < tile.w || source.height < tile.h) {
    stderr.writeln(
      'Error: image ${source.width}x${source.height} is smaller than '
      'tile ${tile.w}x${tile.h}.',
    );
    exit(1);
  }

  // Load CSV if provided
  final csvPath =
      results['csv'] as String? ?? p.setExtension(imagePath, '.csv');
  final csvRows = parseCsvFile(csvPath);

  if (csvRows.isEmpty) {
    stdout.writeln(
      '[SpriteSheet] INFO: No CSV found at "$csvPath".\n'
      '  → Using index-based filenames (0.png, 1.png, ...).',
    );
  }

  // Build index → name mapping
  final indexToName = <int, String>{};
  var autoIdx = 0;
  for (final row in csvRows) {
    final idx = row.number ?? autoIdx++;
    if (idx < totalSlots) indexToName[idx] = row.name;
  }

  final outDir = results['output'] as String;
  final prefix = results['prefix'] as String;
  final format = results['format'] as String;

  final usedNames = <String, int>{};
  var written = 0;

  stdout.writeln('Splitting "$imagePath" → $totalSlots tiles ($columns×$rows)');

  for (var i = 0; i < totalSlots; i++) {
    final col = i % columns;
    final row = i ~/ columns;

    final sprite = img.copyCrop(
      source,
      x: col * tile.w,
      y: row * tile.h,
      width: tile.w,
      height: tile.h,
    );

    final rawName = indexToName.containsKey(i) ? sanitizeName(indexToName[i]!) : '$i';
    final count = usedNames[rawName] ?? 0;
    usedNames[rawName] = count + 1;
    final filename = count == 0 ? rawName : '${rawName}_$count';

    final outPath = p.join(outDir, '$prefix$filename.$format');
    if (format == 'webp') {
      Directory(p.dirname(outPath)).createSync(recursive: true);
      File(outPath).writeAsBytesSync(img.encodeJpg(sprite)); // fallback: image pkg webp support varies
    } else {
      writePng(sprite, outPath);
    }

    written++;
  }

  stdout.writeln('✓ Written $written files to "$outDir/"');
}

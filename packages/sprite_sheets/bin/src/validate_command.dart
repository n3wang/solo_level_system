import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'shared.dart';

/// `spritesheet validate <image> [options]`
///
/// Checks that a spritesheet and its CSV manifest are consistent.
void runValidate(List<String> args) {
  final parser = ArgParser()
    ..addOption('tile', abbr: 't', help: 'Override tile size (e.g. 32 or 32x48).')
    ..addOption('csv', abbr: 'c', help: 'Path to CSV manifest.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    stdout.writeln('Usage: spritesheet validate <image> [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final imagePath = results.rest.first;
  final stem = p.basenameWithoutExtension(imagePath);
  final tile = parseTileSize(results['tile'] as String?, stem);

  bool ok = true;

  // ── Image ──
  final src = decodeFile(imagePath);
  if (src == null) {
    stderr.writeln('✗ Cannot decode "$imagePath".');
    exit(1);
  }

  if (tile == null) {
    stderr.writeln(
      '✗ Cannot determine tile size from "$imagePath".\n'
      '  Rename to "{name}_{W}px.png" or pass --tile.',
    );
    exit(1);
  }

  final columns = src.width ~/ tile.w;
  final rows = src.height ~/ tile.h;
  final totalSlots = columns * rows;
  final remX = src.width % tile.w;
  final remY = src.height % tile.h;

  stdout.writeln('✓ Image: ${src.width}x${src.height} ($columns cols × $rows rows = $totalSlots slots)');
  stdout.writeln('✓ Tile:  ${tile.w}×${tile.h}${tile.w == tile.h ? ' (square)' : ''}');

  if (remX > 0 || remY > 0) {
    stdout.writeln('⚠ Remainder: ${remX}px right, ${remY}px bottom (ignored)');
    ok = false;
  }

  // ── CSV ──
  final csvPath =
      results['csv'] as String? ?? p.setExtension(imagePath, '.csv');
  final csvRows = parseCsvFile(csvPath);

  if (csvRows.isEmpty) {
    stdout.writeln('⚠ No CSV manifest found at "$csvPath".');
    ok = false;
  } else {
    final names = <String>{};
    final dupes = <String>[];
    var outOfRange = 0;

    var autoIdx = 0;
    for (final row in csvRows) {
      final idx = row.number ?? autoIdx++;
      if (idx >= totalSlots) outOfRange++;
      if (!names.add(row.name)) dupes.add(row.name);
    }

    stdout.writeln('✓ CSV: ${csvRows.length} entries');

    if (outOfRange > 0) {
      stdout.writeln('✗ $outOfRange entries reference out-of-range indices.');
      ok = false;
    }

    if (dupes.isNotEmpty) {
      stdout.writeln('✗ Duplicate names: ${dupes.join(', ')}');
      ok = false;
    }

    final unnamed = totalSlots - csvRows.length;
    if (unnamed > 0) {
      stdout.writeln('⚠ $unnamed grid slots have no CSV name.');
    }

    if (outOfRange == 0 && dupes.isEmpty) {
      stdout.writeln('✓ All CSV entries are valid.');
    }
  }

  stdout.writeln(ok ? '\n✓ Validation passed.' : '\n⚠ Validation completed with warnings.');
}

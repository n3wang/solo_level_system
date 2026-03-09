import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'shared.dart';

/// `spritesheet info <image>`
///
/// Prints a quick summary of a spritesheet without modifying any files.
void runInfo(List<String> args) {
  final parser = ArgParser()
    ..addOption('tile', abbr: 't', help: 'Override tile size.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    stdout.writeln('Usage: spritesheet info <image> [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final imagePath = results.rest.first;
  final stem = p.basenameWithoutExtension(imagePath);
  final tile = parseTileSize(results['tile'] as String?, stem);

  final src = decodeFile(imagePath);
  if (src == null) {
    stderr.writeln('Error: cannot decode "$imagePath".');
    exit(1);
  }

  stdout.writeln('File:  $imagePath');
  stdout.writeln('Size:  ${src.width}×${src.height}');

  if (tile == null) {
    stdout.writeln('Tile:  unknown (filename does not match convention)');
    return;
  }

  final columns = src.width ~/ tile.w;
  final rows = src.height ~/ tile.h;
  stdout.writeln('Tile:  ${tile.w}×${tile.h}');
  stdout.writeln('Grid:  $columns × $rows');
  stdout.writeln('Slots: ${columns * rows}');

  // Check for CSV
  final csvPath = p.setExtension(imagePath, '.csv');
  final csvRows = parseCsvFile(csvPath);
  if (csvRows.isEmpty) {
    stdout.writeln('CSV:   not found');
  } else {
    stdout.writeln('CSV:   $csvPath (${csvRows.length} named sprites)');
  }
}

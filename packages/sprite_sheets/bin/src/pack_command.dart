import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'shared.dart';

/// `spritesheet pack <directory> [options]`
///
/// Packs individual image files into a single spritesheet + CSV manifest.
void runPack(List<String> args) {
  final parser = ArgParser()
    ..addOption('size',
        abbr: 's',
        mandatory: true,
        help: 'Tile size: 32 (square) or 32x48 (non-square).')
    ..addOption('output',
        abbr: 'o', help: 'Output filename stem (without extension).')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    stdout.writeln('Usage: spritesheet pack <directory> [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final dirPath = results.rest.first;
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    stderr.writeln('Error: directory "$dirPath" does not exist.');
    exit(1);
  }

  final tile = parseTileSize(results['size'] as String?, '');
  if (tile == null) {
    stderr.writeln('Error: invalid --size value.');
    exit(1);
  }

  // Collect image files sorted alphabetically
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png') || f.path.endsWith('.jpg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('No .png/.jpg files found in "$dirPath".');
    exit(1);
  }

  final count = files.length;
  final columns = max(1, sqrt(count).ceil());
  final rows = (count / columns).ceil();

  final sheetW = columns * tile.w;
  final sheetH = rows * tile.h;
  final sheet = img.Image(width: sheetW, height: sheetH);

  final stem =
      results['output'] as String? ?? '${p.basename(dirPath)}_${tile.w}x${tile.h}px';

  final csvLines = ['name,number'];

  for (var i = 0; i < files.length; i++) {
    final col = i % columns;
    final row = i ~/ columns;

    final src = decodeFile(files[i].path);
    if (src == null) {
      stderr.writeln('Warning: cannot decode "${files[i].path}", skipping.');
      continue;
    }

    final resized = img.copyResize(src, width: tile.w, height: tile.h);
    img.compositeImage(
      sheet,
      resized,
      dstX: col * tile.w,
      dstY: row * tile.h,
    );

    final name = p.basenameWithoutExtension(files[i].path);
    csvLines.add('$name,$i');
  }

  writePng(sheet, '$stem.png');
  File('$stem.csv').writeAsStringSync(csvLines.join('\n'));

  stdout.writeln('✓ Packed ${files.length} sprites → "$stem.png" + "$stem.csv"');
  stdout.writeln('  Grid: ${columns}×$rows, tile: ${tile.w}×${tile.h}');
}

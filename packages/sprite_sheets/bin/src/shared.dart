import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Parse tile size from a filename stem or explicit --tile argument.
/// Returns null if it can't be determined.
({int w, int h})? parseTileSize(String? tileArg, String stem) {
  if (tileArg != null) {
    final parts = tileArg.split('x');
    if (parts.length == 1) {
      final v = int.tryParse(parts[0]);
      if (v != null) return (w: v, h: v);
    } else if (parts.length == 2) {
      final w = int.tryParse(parts[0]);
      final h = int.tryParse(parts[1]);
      if (w != null && h != null) return (w: w, h: h);
    }
    stderr.writeln('Error: invalid --tile value "$tileArg". Expected 32 or 32x48.');
    return null;
  }

  // Parse from filename convention: {name}_{W}px or {name}_{W}x{H}px
  final regex = RegExp(r'^.+?_(\d+)(?:x(\d+))?px$');
  final match = regex.firstMatch(stem);
  if (match == null) return null;
  final w = int.parse(match.group(1)!);
  final h = match.group(2) != null ? int.parse(match.group(2)!) : w;
  return (w: w, h: h);
}

/// Sanitize a sprite name into a safe filename stem.
String sanitizeName(String name) {
  return name
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
}

/// Parse a CSV file into (name, index?) rows. Returns empty on failure.
List<({String name, int? number})> parseCsvFile(String csvPath) {
  final file = File(csvPath);
  if (!file.existsSync()) return [];

  var content = file.readAsStringSync();
  if (content.startsWith('\uFEFF')) content = content.substring(1);

  final lines = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
      .toList();

  if (lines.isEmpty) return [];

  final headers =
      lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
  final nameIdx = headers.indexOf('name');
  final numberIdx = headers.indexOf('number');

  if (nameIdx < 0) {
    // No header — every line is a name
    return lines.map((l) => (name: l.trim(), number: null as int?)).toList();
  }

  final rows = <({String name, int? number})>[];
  for (var i = 1; i < lines.length; i++) {
    final cells = lines[i].split(',');
    final name = nameIdx < cells.length ? cells[nameIdx].trim() : '';
    if (name.isEmpty) continue;
    final number = (numberIdx >= 0 && numberIdx < cells.length)
        ? int.tryParse(cells[numberIdx].trim())
        : null;
    rows.add((name: name, number: number));
  }
  return rows;
}

/// Decode an image file using the `image` package.
img.Image? decodeFile(String path) {
  final bytes = File(path).readAsBytesSync();
  return img.decodeImage(bytes);
}

/// Encode and write an [img.Image] as PNG to [outPath].
void writePng(img.Image image, String outPath) {
  final dir = p.dirname(outPath);
  Directory(dir).createSync(recursive: true);
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

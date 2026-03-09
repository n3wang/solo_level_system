/// A single parsed row from a sprite CSV manifest.
class ParsedCsvRow {
  final String name;
  final int? number;
  final Map<String, String> metadata;

  const ParsedCsvRow({
    required this.name,
    this.number,
    this.metadata = const {},
  });
}

/// Parses CSV sprite manifests.
///
/// Supported formats:
///
/// Minimal (index = row order):
///   name
///   sword
///   shield
///
/// Explicit index:
///   name,number
///   sword,0
///   shield,5
///
/// Extended metadata:
///   name,number,tags,category
///   sword,0,weapon;melee,equipment
class CsvParser {
  static List<ParsedCsvRow> parse(String content) {
    var normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Strip BOM
    if (normalized.startsWith('\uFEFF')) normalized = normalized.substring(1);

    final lines = normalized
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
        .toList();

    if (lines.isEmpty) return [];

    final headers = _splitLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
    final nameIdx = headers.indexOf('name');
    final numberIdx = headers.indexOf('number');

    // No recognised header row — treat every line as a bare name in order
    if (nameIdx < 0) {
      return lines.map((line) => ParsedCsvRow(name: line.trim())).toList();
    }

    final rows = <ParsedCsvRow>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = _splitLine(lines[i]);
      if (cells.isEmpty) continue;

      final name = nameIdx < cells.length ? cells[nameIdx].trim() : '';
      if (name.isEmpty) continue;

      final number = (numberIdx >= 0 && numberIdx < cells.length)
          ? int.tryParse(cells[numberIdx].trim())
          : null;

      final metadata = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        if (j == nameIdx || j == numberIdx) continue;
        if (j < cells.length) metadata[headers[j]] = cells[j].trim();
      }

      rows.add(ParsedCsvRow(name: name, number: number, metadata: metadata));
    }

    return rows;
  }

  static List<String> _splitLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }
}

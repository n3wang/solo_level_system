import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'csv_parser.dart';
import 'grid_calculator.dart';
import 'loaded_sheet.dart';
import 'missing_sprite_behavior.dart';
import 'naming_convention.dart';
import 'sheet_source.dart';
import 'sprite_entry.dart';

/// Central registry and cache for all spritesheets.
///
/// Call [SpriteSheets.init] once (typically in `main()` or before first use),
/// then access sheets with [SpriteSheets.of].
///
/// ```dart
/// await SpriteSheets.init(
///   sheets: [
///     SheetSource.asset('assets/icons_32px.png'),
///   ],
/// );
///
/// // In a widget:
/// SpriteImage(sheet: 'icons_32px', name: 'sword')
/// ```
class SpriteSheets {
  SpriteSheets._();

  static final SpriteSheets _instance = SpriteSheets._();

  // Exposed for internal widget/provider use.
  static SpriteSheets get instance => _instance;

  final Map<String, LoadedSheet> _cache = {};
  MissingSpriteBehavior _missingBehavior = MissingSpriteBehavior.placeholder;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Load and cache all sheets described by [sheets].
  ///
  /// Safe to call multiple times — already-loaded sheets are skipped.
  static Future<void> init({
    required List<SheetSource> sheets,
    MissingSpriteBehavior onMissing = MissingSpriteBehavior.placeholder,
  }) async {
    _instance._missingBehavior = onMissing;
    await Future.wait(sheets.map(_instance._loadSheet));
  }

  /// Synchronous access to an already-loaded sheet by its derived name.
  ///
  /// Returns null if the sheet was never loaded (or loading failed).
  static LoadedSheet? of(String sheetName) => _instance._cache[sheetName];

  /// Async access — returns null when the sheet is absent.
  Future<LoadedSheet?> getSheet(String sheetName) async =>
      _cache[sheetName];

  /// The [MissingSpriteBehavior] set during [init].
  MissingSpriteBehavior get missingBehavior => _missingBehavior;

  /// Evict all cached sheets (e.g. for memory pressure or hot-reload).
  static void clearCache() => _instance._cache.clear();

  // ── Loading ─────────────────────────────────────────────────────────────────

  Future<void> _loadSheet(SheetSource source) async {
    final stem = NamingConvention.stemFrom(source.assetPath);
    final parsed = NamingConvention.parse(stem);

    final tileW = source.tileWidth ?? parsed?.tileWidth;
    final tileH = source.tileHeight ?? parsed?.tileHeight;
    final sheetName = parsed?.name ?? stem;

    if (_cache.containsKey(sheetName)) return; // already loaded

    if (tileW == null || tileH == null) {
      _log(
        '[SpriteSheet] WARNING: Cannot determine tile size for '
        '\'${source.assetPath}\'.\n'
        '  → Filename does not match convention ({name}_{W}px.ext or '
        '{name}_{W}x{H}px.ext).\n'
        '  → Provide tileWidth/tileHeight explicitly in SheetSource.asset().',
      );
      return;
    }

    // ── Decode image ──
    ui.Image image;
    try {
      final data = await rootBundle.load(source.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      image = frame.image;
    } catch (e) {
      _log('[SpriteSheet] ERROR: Failed to load \'${source.assetPath}\': $e');
      return;
    }

    // ── Calculate grid ──
    GridInfo grid;
    try {
      final result = GridCalculator.calculate(
        imageWidth: image.width,
        imageHeight: image.height,
        tileWidth: tileW,
        tileHeight: tileH,
        sheetName: sheetName,
      );
      for (final w in result.warnings) {
        _log(w);
      }
      grid = result.info;
    } on InvalidGridException catch (e) {
      _log(e.message);
      return;
    }

    // ── Load CSV manifest ──
    List<ParsedCsvRow> csvRows = [];
    final csvPath = source.csvPath ?? _inferCsvPath(source.assetPath);
    try {
      final raw = await rootBundle.loadString(csvPath);
      csvRows = CsvParser.parse(raw);
    } catch (_) {
      _log(
        '[SpriteSheet] INFO: No CSV found for \'${source.assetPath}\'.\n'
        '  → Sprites accessible by index only (0 to ${grid.totalSlots - 1}).\n'
        '  → Create \'$csvPath\' with a \'name\' column to enable name lookup.',
      );
    }

    // ── Build entries ──
    final entries = _buildEntries(csvRows, grid, sheetName);
    _cache[sheetName] = LoadedSheet(image: image, grid: grid, entries: entries);
  }

  List<SpriteEntry> _buildEntries(
    List<ParsedCsvRow> rows,
    GridInfo grid,
    String sheetName,
  ) {
    if (rows.length > grid.totalSlots) {
      _log(
        '[SpriteSheet] WARNING: CSV has ${rows.length} entries but the grid '
        'only has ${grid.totalSlots} slots.\n'
        '  → Entries beyond index ${grid.totalSlots - 1} will be ignored.',
      );
    } else if (rows.isNotEmpty && rows.length < grid.totalSlots) {
      _log(
        '[SpriteSheet] INFO: CSV maps ${rows.length} of ${grid.totalSlots} '
        'available grid slots.\n'
        '  → ${grid.totalSlots - rows.length} slots are unnamed.',
      );
    }

    final entries = <SpriteEntry>[];
    var autoIndex = 0;

    for (final row in rows) {
      final index = row.number ?? autoIndex++;

      if (index >= grid.totalSlots) {
        _log(
          '[SpriteSheet] WARNING: Sprite \'${row.name}\' references index '
          '$index, but \'$sheetName\' grid has ${grid.totalSlots} slots '
          '(0–${grid.totalSlots - 1}).\n'
          '  → Skipping \'${row.name}\'.',
        );
        continue;
      }

      final col = index % grid.columns;
      final row2 = index ~/ grid.columns;
      final rect = ui.Rect.fromLTWH(
        (col * grid.tileWidth).toDouble(),
        (row2 * grid.tileHeight).toDouble(),
        grid.tileWidth.toDouble(),
        grid.tileHeight.toDouble(),
      );

      entries.add(SpriteEntry(
        name: row.name,
        index: index,
        sourceRect: rect,
        metadata: row.metadata,
      ));
    }

    return entries;
  }

  // ── Fuzzy match (Levenshtein distance ≤ 2) ─────────────────────────────────

  /// Suggest the closest name in [candidates] to [query], or null if none
  /// within distance 2.
  static String? suggest(String query, Iterable<String> candidates) {
    String? best;
    var bestDist = 3; // threshold

    for (final c in candidates) {
      final d = _levenshtein(query.toLowerCase(), c.toLowerCase());
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final row = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var prev = row[0];
      row[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final temp = row[j];
        row[j] = a[i - 1] == b[j - 1]
            ? prev
            : 1 + [prev, row[j], row[j - 1]].reduce((a, b) => a < b ? a : b);
        prev = temp;
      }
    }
    return row[b.length];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _inferCsvPath(String imagePath) {
    final dotIndex = imagePath.lastIndexOf('.');
    return dotIndex >= 0
        ? '${imagePath.substring(0, dotIndex)}.csv'
        : '$imagePath.csv';
  }

  static void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }
}

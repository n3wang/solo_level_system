import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_model.dart';

/// Seeds the three unwired CSV-backed decks — D&D 5e monsters, NPC portraits,
/// and the mixed Floriography/Ornithography/Art/History deck — as
/// `CardType.collection` cards, differentiated by `category`
/// (`dnd5e` / `npc` / `floriography` / `ornithography` / `art` / `history` /
/// `mythology`). Those categories feed `CharacterStatsService.statForCard`.
///
/// Idempotent: cards are keyed by a stable id and only their presentation
/// fields (title/description/category/rarity/pointsCost/metadata) are
/// refreshed on re-seed — acquisition state is never touched.
class CollectibleDeckSeedService {
  CollectibleDeckSeedService._();

  static const String _boxName = 'motivationItems';
  static const String _dnd5ePath = 'assets/data/dnd5e.csv';
  static const String _npcPath = 'assets/data/npcx250x360.csv';
  static const String _decksPath = 'assets/data/cards_128x185.csv';

  static const String _dnd5eImageDir = 'assets/images/icon/dnd5e';
  static const String _npcImageDir = 'assets/images/icon/npcx250x360';
  static const String _decksImageDir = 'assets/images/icon/c128x185';

  static Future<void> ensureSeeded() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CardModel>(_boxName);
    }
    final box = Hive.box<CardModel>(_boxName);
    await _seedDnd5e(box);
    await _seedNpc(box);
    await _seedDecks(box);
  }

  // ---- dnd5e -----------------------------------------------------------

  static Future<void> _seedDnd5e(Box<CardModel> box) async {
    try {
      final rows = await _loadCsvRows(_dnd5ePath);
      for (final row in rows) {
        final uniqueId = (row['unique_id'] ?? '').trim();
        final name = (row['creature_name'] ?? '').trim();
        if (uniqueId.isEmpty || name.isEmpty) continue;

        final cr = (row['cr'] ?? '').trim();
        final type = (row['type'] ?? '').trim();
        final size = (row['size'] ?? '').trim();
        final ac = (row['AC'] ?? '').trim();
        final hp = (row['hp'] ?? '').trim();
        final speed = (row['speed'] ?? '').trim();
        final alignment = (row['alignment'] ?? '').trim();
        final legendary =
            (row['legendary'] ?? '').trim().toLowerCase() == 'true';

        final crValue = _parseCr(cr);
        final descriptionParts = <String>[
          if (type.isNotEmpty) type,
          if (size.isNotEmpty) size,
          'CR $cr',
          if (ac.isNotEmpty) 'AC $ac',
          if (hp.isNotEmpty) 'HP $hp',
          if (speed.isNotEmpty) 'Speed: $speed',
          if (alignment.isNotEmpty) alignment,
          if (legendary) 'Legendary',
        ];

        await _upsert(
          box,
          _makeCard(
            id: 'dnd5e_$uniqueId',
            title: name,
            description: descriptionParts.join(' · '),
            category: 'dnd5e',
            pointsCost: _pointsCostForCr(crValue),
            rarity: _rarityForCr(crValue, legendary),
            imageAsset: '$_dnd5eImageDir/$uniqueId.jpg',
            source: 'dnd5e_csv',
          ),
        );
      }
    } catch (_) {
      // Missing/malformed asset must not break the rest of seeding.
    }
  }

  static double _parseCr(String raw) {
    final s = raw.trim();
    if (s.contains('/')) {
      final parts = s.split('/');
      final n = double.tryParse(parts[0].trim()) ?? 0;
      final d = double.tryParse(parts.length > 1 ? parts[1].trim() : '') ?? 1;
      return d == 0 ? 0 : n / d;
    }
    return double.tryParse(s) ?? 0;
  }

  static const List<String> _rarityOrder = [
    'common',
    'uncommon',
    'rare',
    'epic',
  ];

  static String _rarityForCr(double cr, bool legendary) {
    var base = 'common';
    if (cr >= 15) {
      base = 'epic';
    } else if (cr >= 8) {
      base = 'rare';
    } else if (cr >= 3) {
      base = 'uncommon';
    }
    if (!legendary) return base;
    final baseIndex = _rarityOrder.indexOf(base);
    final rareIndex = _rarityOrder.indexOf('rare');
    return _rarityOrder[baseIndex < rareIndex ? rareIndex : baseIndex];
  }

  static int _pointsCostForCr(double cr) {
    if (cr >= 15) return 80;
    if (cr >= 8) return 50;
    if (cr >= 3) return 25;
    return 10;
  }

  // ---- npc ---------------------------------------------------------------

  static Future<void> _seedNpc(Box<CardModel> box) async {
    try {
      final rows = await _loadCsvRows(_npcPath);
      for (final row in rows) {
        final id = (row['id'] ?? '').trim();
        final character = (row['character'] ?? '').trim();
        final state = (row['state'] ?? '').trim();
        if (id.isEmpty || character.isEmpty || state.isEmpty) continue;

        final characterTitled = _titleCase(character);
        final stateTitled = _titleCase(state);

        await _upsert(
          box,
          _makeCard(
            id: 'npc_$id',
            title: '$characterTitled ($stateTitled)',
            description: 'A glimpse of $characterTitled, feeling $state.',
            category: 'npc',
            pointsCost: 10,
            rarity: state.toLowerCase() == 'happy' ? 'uncommon' : 'common',
            imageAsset: '$_npcImageDir/$id.png',
            source: 'npcx250x360_csv',
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // ---- decks (cards_128x185.csv) -----------------------------------------

  static Future<void> _seedDecks(Box<CardModel> box) async {
    try {
      final rows = await _loadCsvRows(_decksPath, lenientUtf8: true);
      final usedIds = <String>{};
      for (final row in rows) {
        final name = (row['name'] ?? '').trim();
        if (name.isEmpty) continue;

        final description = (row['description'] ?? '').trim();
        final numberMatch = RegExp(
          r'\d+',
        ).firstMatch((row['number'] ?? '').trim());
        final number = numberMatch != null
            ? int.tryParse(numberMatch.group(0)!)
            : null;

        final category = _categoryForDeckRow(
          (row['category'] ?? '').trim().toLowerCase(),
          number,
        );

        final idKey = number != null ? '$number' : _slug(name);
        var id = 'deck128_$idKey';
        var suffix = 1;
        while (usedIds.contains(id)) {
          suffix++;
          id = 'deck128_${idKey}_$suffix';
        }
        usedIds.add(id);

        final imageKey = number != null ? '$number' : _slug(name);

        await _upsert(
          box,
          _makeCard(
            id: id,
            title: name,
            description: description.isEmpty ? category : description,
            category: category,
            pointsCost: 15,
            rarity: 'common',
            imageAsset: '$_decksImageDir/$imageKey.png',
            source: 'cards_128x185_csv',
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  static String _categoryForDeckRow(String rawCategory, int? number) {
    if (rawCategory.isNotEmpty) return rawCategory;
    if (number != null && number >= 202 && number <= 221) return 'art';
    if (number != null && number >= 222 && number <= 248) return 'mythology';
    return 'history';
  }

  // ---- shared helpers ------------------------------------------------------

  static String _slug(String s) {
    var out = s.toLowerCase().replaceAll("'", '');
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    out = out.replaceAll(RegExp(r'^-+|-+$'), '');
    return out;
  }

  static CardModel _makeCard({
    required String id,
    required String title,
    required String description,
    required String category,
    required int pointsCost,
    required String rarity,
    required String imageAsset,
    required String source,
  }) {
    final now = DateTime.now();
    return CardModel(
      id: id,
      type: 'collection',
      title: title,
      description: description,
      category: category,
      pointsCost: pointsCost,
      createdAt: now,
      isSystem: true,
      rarity: rarity,
      metadata: {'source': source, 'imageAsset': imageAsset},
    );
  }

  static Future<void> _upsert(Box<CardModel> box, CardModel card) async {
    final existing = box.values.where((c) => c.id == card.id).firstOrNull;
    if (existing == null) {
      await box.add(card);
      return;
    }
    existing
      ..title = card.title
      ..description = card.description
      ..category = card.category
      ..pointsCost = card.pointsCost
      ..rarity = card.rarity
      ..metadata = card.metadata;
    await existing.save();
  }

  /// Loads a CSV asset and parses it into a list of header-keyed row maps.
  /// [lenientUtf8] decodes with `allowMalformed: true` for assets known to
  /// contain invalid UTF-8 bytes (e.g. mojibake apostrophes).
  static Future<List<Map<String, String>>> _loadCsvRows(
    String path, {
    bool lenientUtf8 = false,
  }) async {
    final content = lenientUtf8
        ? await _loadStringLeniently(path)
        : await rootBundle.loadString(path);
    final rows = _parseCsv(content);
    if (rows.length <= 1) return const [];

    final header = rows.first.map((h) => h.trim()).toList();
    final result = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final raw = rows[i];
      if (raw.length == 1 && raw.first.trim().isEmpty) continue;
      final map = <String, String>{};
      for (var c = 0; c < header.length; c++) {
        map[header[c]] = c < raw.length ? raw[c] : '';
      }
      result.add(map);
    }
    return result;
  }

  static Future<String> _loadStringLeniently(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Minimal RFC4180-ish CSV parser: comma-delimited, double-quoted fields
  /// may contain commas/newlines, `""` is an escaped quote. Needed because
  /// `cards_128x185.csv` has quoted fields with embedded commas that a naive
  /// line-then-split parser would corrupt.
  static List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var i = 0;
    final len = content.length;

    while (i < len) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < len && content[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.write(ch);
        i++;
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (ch == ',') {
        row.add(field.toString());
        field.clear();
        i++;
        continue;
      }
      if (ch == '\r') {
        i++;
        continue;
      }
      if (ch == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = [];
        i++;
        continue;
      }
      field.write(ch);
      i++;
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

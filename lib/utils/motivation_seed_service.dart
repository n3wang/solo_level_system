import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/motivation_item_model.dart';

class MotivationSeedService {
  static const String _boxName = 'motivationItems';
  static const String _csvPath = 'assets/icon/motivation_64.csv';
  static const String _quotesPath = 'assets/quotes.csv';

  static Future<void> ensureSeeded() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<MotivationItemModel>(_boxName);
    }
    final box = Hive.box<MotivationItemModel>(_boxName);
    final quoteMap = await _loadQuotesByPerson();
    final csvRaw = await rootBundle.loadString(_csvPath);
    final lines = csvRaw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) return;

    for (var i = 1; i < lines.length; i++) {
      final columns = _parse4Columns(lines[i]);
      if (columns == null) continue;
      final name = columns[0].trim();
      final number = int.tryParse(columns[1].trim());
      final description = columns[2].trim();
      final category = columns[3].trim().toLowerCase();
      if (name.isEmpty || number == null) continue;

      final type = _typeFromCategory(category);
      final id = 'motivation_catalog_$number';
      final exists = box.values.any((item) => item.id == id);
      if (exists) continue;

      final quotes = quoteMap[name] ?? _findQuotesByContains(quoteMap, name);
      final quoteText = type == 'quote' && quotes.isNotEmpty
          ? quotes[number % quotes.length]
          : null;

      await box.add(
        MotivationItemModel(
          id: id,
          type: type,
          title: name,
          description: description,
          category: category,
          pointsCost: _pointsCost(number: number, type: type),
          createdAt: DateTime.now(),
          isSystem: true,
          quotePerson: type == 'quote' ? name : null,
          quoteText: quoteText,
          imageIndex: number,
          metadata: {'source': 'motivation_64.csv'},
        ),
      );
    }
  }

  static Future<Map<String, List<String>>> _loadQuotesByPerson() async {
    final map = <String, List<String>>{};
    final raw = await rootBundle.loadString(_quotesPath);
    final lines = raw.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.length <= 1) return map;
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      final commaIndex = line.indexOf(',');
      if (commaIndex <= 0 || commaIndex >= line.length - 1) continue;
      final person = line.substring(0, commaIndex).trim();
      var quotesRaw = line.substring(commaIndex + 1).trim();
      quotesRaw = quotesRaw.replaceAll('"', '');
      final quotes = quotesRaw
          .split(';')
          .map((q) => q.trim())
          .where((q) => q.isNotEmpty)
          .toList();
      if (person.isNotEmpty && quotes.isNotEmpty) {
        map[person] = quotes;
      }
    }
    return map;
  }

  static List<String> _findQuotesByContains(
    Map<String, List<String>> quoteMap,
    String personName,
  ) {
    final normalized = personName.toLowerCase();
    for (final entry in quoteMap.entries) {
      if (entry.key.toLowerCase().contains(normalized) ||
          normalized.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return const [];
  }

  static List<String>? _parse4Columns(String line) {
    final parts = line.split(',');
    if (parts.length < 4) return null;
    final name = parts[0];
    final number = parts[1];
    final category = parts.last;
    final description = parts.sublist(2, parts.length - 1).join(',').trim();
    return [name, number, description, category];
  }

  static String _typeFromCategory(String category) {
    if (category == 'philosopher') return 'quote';
    if (category == 'boardgame' || category == 'plant') return 'collection';
    return 'collection';
  }

  static int _pointsCost({required int number, required String type}) {
    if (number <= 3) return 20;
    if (type == 'quote') return 15;
    if (number <= 20) return 30;
    return 45;
  }
}


import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:yaml/yaml.dart';

class MotivationSeedService {
  static const String _boxName = 'motivationItems';
  static const String _csvPath = 'assets/data/cards_catalog.csv';
  static const String _quotesPath = 'assets/data/quotes.csv';
  static const String _guidesPath = 'assets/data/guides.yml';
  static const String _optionsPath = 'assets/data/options.yml';
  static const String _testSourceTag = 'test_sample_gym_quotes';

  static Future<void> ensureSeeded() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CardModel>(_boxName);
    }
    final box = Hive.box<CardModel>(_boxName);
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
      final quotes = quoteMap[name] ?? _findQuotesByContains(quoteMap, name);
      final quoteText = type == 'quote' && quotes.isNotEmpty
          ? quotes.first
          : null;
      CardModel? existing;
      for (final item in box.values) {
        if (item.id == id) {
          existing = item;
          break;
        }
      }
      if (existing != null) {
        if (type == 'quote' && quotes.isNotEmpty) {
          var changed = false;
          final metadata = Map<String, dynamic>.from(existing.metadata);
          final existingQuotes = metadata['quotes'];
          final hasQuotes = existingQuotes is List && existingQuotes.isNotEmpty;
          if (!hasQuotes) {
            metadata['quotes'] = quotes;
            existing.metadata = metadata;
            changed = true;
          }
          if ((existing.quoteText?.trim().isEmpty ?? true)) {
            existing.quoteText = quotes.first;
            changed = true;
          }
          if (existing.description.trim().isEmpty && description.isNotEmpty) {
            existing.description = description;
            changed = true;
          }
          if (changed) {
            await existing.save();
          }
        }
        continue;
      }

      await box.add(
        CardModel(
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
          rarity: _rarityFor(number),
          metadata: {
            'source': 'cards_catalog.csv',
            if (type == 'quote' && quotes.isNotEmpty) 'quotes': quotes,
          },
        ),
      );
    }

    await _ensureConfiguredCards(box);

    if (AppEnvironment.isTest) {
      await _ensureTestSampleGymQuotes(box);
    }
  }

  /// Seeds guide and option cards from YAML while preserving player progress.
  static Future<void> _ensureConfiguredCards(Box<CardModel> box) async {
    await _seedConfiguredCards(box, _optionsPath, 'options', 'option');
    await _seedConfiguredCards(box, _guidesPath, 'guides', 'guide');
  }

  static Future<void> _seedConfiguredCards(
    Box<CardModel> box,
    String path,
    String listKey,
    String type,
  ) async {
    final document = loadYaml(await rootBundle.loadString(path));
    final entries = document[listKey];
    if (entries is! YamlList) return;

    for (final raw in entries) {
      if (raw is! Map) continue;
      final slug = (raw['id'] ?? '').toString().trim();
      final title = (raw['title'] ?? '').toString().trim();
      if (slug.isEmpty || title.isEmpty) continue;

      final copies = int.tryParse('${raw['starter_copies'] ?? 0}') ?? 0;
      final now = DateTime.now();
      final targetKey = type == 'option' ? 'setting_key' : 'screen_key';
      final targetId = (raw[targetKey] ?? '').toString().trim();
      final metadata = <String, dynamic>{
        'source': '${type}_yaml',
        if (type == 'option') ...{
          'settingKey': targetId,
          'capacityPerCopy':
              int.tryParse('${raw['capacity_per_copy'] ?? 1}') ?? 1,
        },
        if (type == 'guide') ...{
          'screenKey': targetId,
          'howTo': (raw['how_to'] ?? '').toString(),
          'tips': _yamlStringList(raw['tips']),
        },
      };
      final card = CardModel(
        id: '${type}_$slug',
        type: type,
        title: title,
        description: (raw['description'] ?? '').toString(),
        category: type,
        pointsCost: AppEnvironment.isTest && type == 'option'
            ? 10
            : (int.tryParse('${raw['points_cost'] ?? 0}') ?? 0),
        createdAt: now,
        isSystem: true,
        isStarter: copies > 0,
        isAcquired: copies > 0,
        acquisitionCount: copies,
        acquisitionHistory: List<DateTime>.filled(copies, now),
        unlockTargetId: targetId.isEmpty ? null : targetId,
        rarity: (raw['rarity'] ?? 'common').toString(),
        metadata: metadata,
      );

      final existing = box.values
          .where((item) => item.id == card.id)
          .firstOrNull;
      if (existing == null) {
        await box.add(card);
        continue;
      }
      existing
        ..title = card.title
        ..description = card.description
        ..category = card.category
        ..pointsCost = card.pointsCost
        ..unlockTargetId = card.unlockTargetId
        ..rarity = card.rarity
        ..metadata = card.metadata;
      await existing.save();
    }
  }

  static List<String> _yamlStringList(dynamic value) {
    if (value is! YamlList) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  /// Rough rarity tiering by catalog number so drops and tints vary.
  static String _rarityFor(int number) {
    if (number <= 3) return 'common';
    if (number <= 12) return 'uncommon';
    if (number <= 24) return 'rare';
    return 'epic';
  }

  static Future<void> _ensureTestSampleGymQuotes(Box<CardModel> box) async {
    final now = DateTime.now();
    final samples = <CardModel>[
      CardModel(
        id: 'test_quote_gym_1',
        type: 'quote',
        title: 'Gym Focus',
        description: 'One more rep than yesterday. That is enough progress.',
        category: 'quote',
        pointsCost: 5,
        createdAt: now,
        isSystem: true,
        quotePerson: 'Gym Focus',
        quoteText: 'One more rep than yesterday. That is enough progress.',
        metadata: const {
          'source': _testSourceTag,
          'isTestSeed': true,
          'quotes': [
            'One more rep than yesterday. That is enough progress.',
            'Do the hard set first, then everything else feels lighter.',
            'Consistency beats intensity when intensity is inconsistent.',
          ],
        },
      ),
      CardModel(
        id: 'test_quote_gym_2',
        type: 'quote',
        title: 'Gym Discipline',
        description: 'You do not need perfect energy. You need your next set.',
        category: 'quote',
        pointsCost: 5,
        createdAt: now,
        isSystem: true,
        quotePerson: 'Gym Discipline',
        quoteText: 'You do not need perfect energy. You need your next set.',
        metadata: const {
          'source': _testSourceTag,
          'isTestSeed': true,
          'quotes': [
            'You do not need perfect energy. You need your next set.',
            'Discipline is deciding before motivation shows up.',
            'Small effort on low-energy days protects big goals.',
          ],
        },
      ),
      CardModel(
        id: 'test_quote_gym_3',
        type: 'quote',
        title: 'Gym Momentum',
        description:
            'Show up. Warm up. Start small. Momentum handles the rest.',
        category: 'quote',
        pointsCost: 5,
        createdAt: now,
        isSystem: true,
        quotePerson: 'Gym Momentum',
        quoteText: 'Show up. Warm up. Start small. Momentum handles the rest.',
        metadata: const {
          'source': _testSourceTag,
          'isTestSeed': true,
          'quotes': [
            'Show up. Warm up. Start small. Momentum handles the rest.',
            'Action creates motivation more often than waiting does.',
            'Finish today so tomorrow starts stronger.',
          ],
        },
      ),
    ];

    for (final sample in samples) {
      final alreadySeeded = box.values.any((item) => item.id == sample.id);
      if (alreadySeeded) continue;
      await box.add(sample);
    }
  }

  static Future<Map<String, List<String>>> _loadQuotesByPerson() async {
    final map = <String, List<String>>{};
    String raw;
    try {
      raw = await rootBundle.loadString(_quotesPath);
    } catch (_) {
      // Keep motivation seeding alive even if quotes asset is unavailable.
      return map;
    }
    final lines = raw
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
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
    if (number <= 3) return AppEnvironment.seededMotivationStarterCost;
    if (type == 'quote') return AppEnvironment.isTest ? 10 : 15;
    if (number <= 20) return AppEnvironment.isTest ? 15 : 30;
    return AppEnvironment.isTest ? 25 : 45;
  }
}

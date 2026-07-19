import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/reward_model.dart';

class RewardSeedService {
  static const String _rewardsBoxName = 'rewards';
  static const String _sourceTag = 'default_boardgame_csv';
  static const String _testSourceTag = 'test_sample_user_rewards';
  static const String _csvAssetPath = 'assets/data/cards_catalog.csv';

  static Future<void> ensureDefaultBoardgameRewards() async {
    if (!Hive.isBoxOpen(_rewardsBoxName)) {
      await Hive.openBox<RewardModel>(_rewardsBoxName);
    }
    final box = Hive.box<RewardModel>(_rewardsBoxName);

    final csvRaw = await rootBundle.loadString(_csvAssetPath);
    final lines = csvRaw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) return;

    // Skip header row.
    for (var i = 1; i < lines.length; i++) {
      final parts = _splitCsvLine(lines[i]);
      if (parts.length < 2) continue;

      final title = parts[0].trim();
      final number = int.tryParse(parts[1].trim());
      final description = parts.length > 2 ? parts[2].trim() : '';
      final csvCategory = parts.length > 3 ? parts[3].trim() : '';
      if (title.isEmpty || number == null) continue;

      final seededId = 'boardgame_reward_$number';
      final alreadySeeded = box.values.any((reward) => reward.id == seededId);
      if (alreadySeeded) continue;

      // Keep demo-friendly unlock costs for first few rewards.
      final pointsCost = (number <= 3) ? 20 : _costForNumber(number);
      await box.add(
        RewardModel(
          id: seededId,
          title: title,
          description: description.isEmpty
              ? 'Collectible boardgame reward for demo unlock flow.'
              : description,
          pointsCost: pointsCost,
          category: 'entertainment',
          iconName: 'sports_esports',
          color: _colorForNumber(number),
          isCustom: false,
          createdAt: DateTime.now(),
          tags: [
            'boardgame',
            'collectible',
            'demo',
            if (csvCategory.isNotEmpty) csvCategory,
            _sourceTag,
          ],
          metadata: {
            'source': _sourceTag,
            'csvCategory': csvCategory,
            'boardgameNumber': number,
            'isCollectible': true,
          },
        ),
      );
    }

    if (AppEnvironment.isTest) {
      await _ensureTestSampleUserRewards(box);
    }
  }

  static Future<void> _ensureTestSampleUserRewards(Box<RewardModel> box) async {
    final samples = <RewardModel>[
      RewardModel(
        id: 'test_user_reward_ps5',
        title: 'Buy PS5',
        description: 'Redeem points toward a PlayStation 5 purchase.',
        pointsCost: 25,
        category: 'electronics',
        iconName: 'sports_esports',
        color: '#42A5F5',
        isCustom: true,
        createdAt: DateTime.now(),
        tags: const ['test', 'sample', 'user-reward', _testSourceTag],
        metadata: const {'source': _testSourceTag, 'isTestSeed': true},
      ),
      RewardModel(
        id: 'test_user_reward_electronics_kit',
        title: 'Electronics Kit Upgrade',
        description: 'Treat yourself to a new electronics prototyping kit.',
        pointsCost: 18,
        category: 'tools',
        iconName: 'memory',
        color: '#26A69A',
        isCustom: true,
        createdAt: DateTime.now(),
        tags: const ['test', 'sample', 'user-reward', _testSourceTag],
        metadata: const {'source': _testSourceTag, 'isTestSeed': true},
      ),
      RewardModel(
        id: 'test_user_reward_coffee_setup',
        title: 'Premium Coffee Setup',
        description: 'Redeem for a better home coffee setup.',
        pointsCost: 12,
        category: 'shopping',
        iconName: 'coffee',
        color: '#FFA726',
        isCustom: true,
        createdAt: DateTime.now(),
        tags: const ['test', 'sample', 'user-reward', _testSourceTag],
        metadata: const {'source': _testSourceTag, 'isTestSeed': true},
      ),
    ];

    for (final sample in samples) {
      final alreadySeeded = box.values.any((reward) => reward.id == sample.id);
      if (alreadySeeded) continue;
      await box.add(sample);
    }
  }

  static int _costForNumber(int number) {
    if (number <= 6) return 40;
    if (number <= 12) return 60;
    if (number <= 18) return 80;
    return 100;
  }

  static String _colorForNumber(int number) {
    const palette = <String>[
      '#7E57C2',
      '#42A5F5',
      '#26A69A',
      '#66BB6A',
      '#FFA726',
      '#EF5350',
    ];
    return palette[number % palette.length];
  }

  static List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
  }
}

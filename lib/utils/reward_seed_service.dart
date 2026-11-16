import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/reward_model.dart';

class RewardSeedService {
  static const String _rewardsBoxName = 'rewards';
  static const String _sourceTag = 'default_boardgame_csv';
  static const String _testSourceTag = 'test_sample_user_rewards';

  /// Historically seeded demo boardgame rewards. Now removes them so they no
  /// longer appear in the cards hub / rewards lists.
  static Future<void> ensureDefaultBoardgameRewards() async {
    if (!Hive.isBoxOpen(_rewardsBoxName)) {
      await Hive.openBox<RewardModel>(_rewardsBoxName);
    }
    final box = Hive.box<RewardModel>(_rewardsBoxName);
    await _pruneBoardgameRewards(box);

    if (AppEnvironment.isTest) {
      await _ensureTestSampleUserRewards(box);
    }
  }

  static Future<void> _pruneBoardgameRewards(Box<RewardModel> box) async {
    final keysToDelete = <dynamic>[];
    for (final entry in box.toMap().entries) {
      final reward = entry.value;
      final fromBoardgameSeed =
          reward.metadata['source'] == _sourceTag ||
          reward.id.startsWith('boardgame_reward_') ||
          reward.tags.contains('boardgame');
      if (fromBoardgameSeed) keysToDelete.add(entry.key);
    }
    for (final key in keysToDelete) {
      await box.delete(key);
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
}

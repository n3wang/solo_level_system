import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/motivation_item_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';

class TestModeBootstrapService {
  TestModeBootstrapService._();

  static Future<void> ensureTestData() async {
    if (!AppEnvironment.isTest) return;

    await RewardSeedService.ensureDefaultBoardgameRewards();
    await MotivationSeedService.ensureSeeded();

    final progressBox = Hive.box<UserProgressModel>('userProgress');
    final motivationBox = Hive.box<MotivationItemModel>('motivationItems');
    final rewardsBox = Hive.box<RewardModel>('rewards');
    final pomodorosBox = Hive.box<PomodoroModel>('pomodoros');
    final workoutSessionsBox = Hive.box<WorkoutSessionModel>('workoutSessions');
    final txBox = Hive.box<MotivationPointsTransactionModel>(
      'motivationPointsTransactions',
    );

    final progress = progressBox.get('progress') ?? UserProgressModel();
    var shouldSaveProgress = false;
    if (progress.availablePoints != 1000) {
      progress.availablePoints = 1000;
      shouldSaveProgress = true;
    }
    if (progress.totalPointsEarned < 1000) {
      progress.totalPointsEarned = 1000;
      shouldSaveProgress = true;
    }
    if (shouldSaveProgress) {
      await progressBox.put('progress', progress);
    }

    await _ensureAcquiredMotivationItems(motivationBox);
    await _ensurePurchasedRewards(rewardsBox);
    await _ensurePomodoroHistory(pomodorosBox);
    await _ensureWorkoutHistory(workoutSessionsBox);
    await _ensureMotivationTransactions(txBox);
  }

  static Future<void> _ensureAcquiredMotivationItems(
    Box<MotivationItemModel> motivationBox,
  ) async {
    final quoteTargets = motivationBox.values
        .where((item) => item.type == 'quote')
        .take(2)
        .toList();
    final collectionTargets = motivationBox.values
        .where((item) => item.type == 'collection')
        .take(2)
        .toList();
    final targets = [...quoteTargets, ...collectionTargets];

    for (final item in targets) {
      if (item.hasAnyAcquisition) continue;
      item.recordAcquisition();
      await item.save();
    }
  }

  static Future<void> _ensurePurchasedRewards(Box<RewardModel> rewardsBox) async {
    final rewardTargets = rewardsBox.values
        .where(
          (reward) =>
              reward.metadata['isCollectible'] != true &&
              reward.metadata['source'] != 'default_boardgame_csv' &&
              !reward.tags.contains('collectible'),
        )
        .take(2)
        .toList();

    for (final reward in rewardTargets) {
      if (reward.timesPurchased > 0) continue;
      reward.purchase();
    }
  }

  static Future<void> _ensurePomodoroHistory(Box<PomodoroModel> pomodorosBox) async {
    final alreadySeeded = pomodorosBox.values.any(
      (p) => (p.project_id ?? '').startsWith('test_seed_'),
    );
    if (alreadySeeded) return;

    final now = DateTime.now();
    final durations = <String>['25', '35', '20', '45', '30', '50', '40'];
    for (var i = 0; i < 14; i++) {
      final dayOffset = i ~/ 2;
      final hourOffset = (i % 2 == 0) ? 9 : 18;
      final baseDay = now.subtract(Duration(days: dayOffset));
      final start = DateTime(
        baseDay.year,
        baseDay.month,
        baseDay.day,
        hourOffset,
        (i % 3) * 10,
      );

      await pomodorosBox.add(
        PomodoroModel(
          startTime: start,
          duration: durations[i % durations.length],
          project_id: 'test_seed_project_${(i % 3) + 1}',
          project_name: 'Test Project ${(i % 3) + 1}',
          dayPomodoroNumber: (i % 4) + 1,
        ),
      );
    }
  }

  static Future<void> _ensureWorkoutHistory(
    Box<WorkoutSessionModel> workoutSessionsBox,
  ) async {
    final alreadySeeded = workoutSessionsBox.values.any(
      (s) => s.id.startsWith('test_seed_workout_'),
    );
    if (alreadySeeded) return;

    final now = DateTime.now();
    final samples = List.generate(6, (i) {
      final start = now.subtract(Duration(days: i * 2 + 1, hours: i % 3));
      final duration = 28 + (i * 6);
      return WorkoutSessionModel(
        id: 'test_seed_workout_${i + 1}',
        routineId: 'test_seed_routine_${(i % 2) + 1}',
        routineName: i.isEven ? 'Strength Builder' : 'Conditioning Blast',
        startTime: start,
        endTime: start.add(Duration(minutes: duration)),
        durationMinutes: duration,
        completedExerciseIds: const ['squat', 'pushup', 'plank'],
        exerciseCompletedSets: const {'squat': 3, 'pushup': 3, 'plank': 2},
        isCompleted: true,
        status: 'completed',
        totalSetsCompleted: 8,
        totalRepsCompleted: 72 + (i * 4),
        caloriesBurned: 220 + (i * 35),
        tags: const ['test_seed', 'gym'],
        location: 'gym',
      );
    });

    for (final session in samples) {
      await workoutSessionsBox.add(session);
    }
  }

  static Future<void> _ensureMotivationTransactions(
    Box<MotivationPointsTransactionModel> txBox,
  ) async {
    final alreadySeeded = txBox.values.any(
      (tx) => tx.id.startsWith('test_seed_tx_'),
    );
    if (alreadySeeded) return;

    final now = DateTime.now();
    final samples = <MotivationPointsTransactionModel>[
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_1',
        kind: 'earned',
        amount: 120,
        source: 'pomodoro_session',
        createdAt: now.subtract(const Duration(days: 1)),
        metadata: const {'minutes': 120},
      ),
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_2',
        kind: 'earned',
        amount: 80,
        source: 'workout_completion',
        createdAt: now.subtract(const Duration(days: 2)),
        metadata: const {'workouts': 2},
      ),
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_3',
        kind: 'spent',
        amount: 45,
        source: 'reward_purchase',
        createdAt: now.subtract(const Duration(days: 3)),
        metadata: const {'rewardId': 'test_user_reward_electronics_kit'},
      ),
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_4',
        kind: 'earned',
        amount: 60,
        source: 'streak_bonus',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_5',
        kind: 'spent',
        amount: 30,
        source: 'collection_unlock',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      MotivationPointsTransactionModel(
        id: 'test_seed_tx_6',
        kind: 'earned',
        amount: 90,
        source: 'pomodoro_session',
        createdAt: now.subtract(const Duration(days: 9)),
        metadata: const {'minutes': 90},
      ),
    ];

    for (final tx in samples) {
      await txBox.add(tx);
    }
  }
}


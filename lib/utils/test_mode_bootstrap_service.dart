import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/models/workout_set_category_model.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/project_seed_service.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';

class TestModeBootstrapService {
  TestModeBootstrapService._();

  static Future<void> ensureTestData() async {
    if (!AppEnvironment.isTest) return;

    await RewardSeedService.ensureDefaultBoardgameRewards();
    await MotivationSeedService.ensureSeeded();

    final progressBox = Hive.box<UserProgressModel>('userProgress');
    final motivationBox = Hive.box<CardModel>('motivationItems');
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
    Box<CardModel> motivationBox,
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
    // Drop legacy "Test Project N" seeds so charts show real sample projects.
    final legacy = pomodorosBox.values
        .where((p) => (p.project_id ?? '').startsWith('test_seed_'))
        .toList();
    for (final p in legacy) {
      await p.delete();
    }

    final alreadySeeded = pomodorosBox.values.any(
      (p) =>
          p.project_id == ProjectSeedService.studiesProjectId ||
          p.project_id == ProjectSeedService.gamesStudyingProjectId,
    );
    if (alreadySeeded) return;

    await ProjectSeedService.ensureSampleProjects();

    const projects = [
      (ProjectSeedService.studiesProjectId, 'Studies Assignments'),
      (ProjectSeedService.gamesStudyingProjectId, 'Games and Studying'),
    ];

    final now = DateTime.now();
    final durations = <int>[25, 35, 20, 45, 30, 50, 40];
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
      final minutes = durations[i % durations.length];
      final project = projects[i % projects.length];

      await pomodorosBox.add(
        PomodoroModel(
          startTime: start,
          duration: minutes.toString(),
          durationMinutes: minutes,
          project_id: project.$1,
          project_name: project.$2,
          dayPomodoroNumber: (i % 4) + 1,
        ),
      );
    }
  }

  static Future<void> _ensureWorkoutHistory(
    Box<WorkoutSessionModel> workoutSessionsBox,
  ) async {
    final legacy = workoutSessionsBox.values
        .where((s) => s.id.startsWith('test_seed_workout_'))
        .toList();
    for (final s in legacy) {
      await s.delete();
    }

    final alreadySeeded = workoutSessionsBox.values.any(
      (s) => s.id.startsWith('test_seed_set_workout_'),
    );
    if (alreadySeeded) return;

    if (!Hive.isBoxOpen('workoutSetCategories')) {
      await Hive.openBox<WorkoutSetCategoryModel>('workoutSetCategories');
    }
    final sets = Hive.box<WorkoutSetCategoryModel>('workoutSetCategories')
        .values
        .where((s) => s.isActive)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    if (sets.isEmpty) return;

    final now = DateTime.now();
    final samples = List.generate(sets.length.clamp(1, 5) * 2, (i) {
      final set = sets[i % sets.length];
      final start = now.subtract(Duration(days: i, hours: i % 3));
      final duration = 28 + (i * 6);
      return WorkoutSessionModel(
        id: 'test_seed_set_workout_${i + 1}',
        routineId: set.id,
        routineName: set.name,
        startTime: start,
        endTime: start.add(Duration(minutes: duration)),
        durationMinutes: duration,
        completedExerciseIds: set.exerciseIds.take(3).toList(),
        exerciseCompletedSets: {
          for (final id in set.exerciseIds.take(3)) id: 3,
        },
        isCompleted: true,
        status: 'completed',
        totalSetsCompleted: 8,
        totalRepsCompleted: 72 + (i * 4),
        tags: const ['test_seed', 'set'],
        location: 'gym',
        additionalData: {
          'setCategoryId': set.id,
          'setLabel': String.fromCharCode(65 + (i % 3)),
        },
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


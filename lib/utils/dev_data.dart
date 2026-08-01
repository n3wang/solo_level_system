import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/utils/project_seed_service.dart';
import 'package:solo_level_system/utils/test_mode_bootstrap_service.dart';

/// Runtime gate + soft-hide helpers for development / test seed data.
///
/// Records stay in Hive when disabled; UI lists should skip [isDevRecord]
/// unless [AppEnvironment.isTest] is true again.
class DevData {
  DevData._();

  static const Set<String> sampleProjectIds = {
    ProjectSeedService.personalProjectsId,
    ProjectSeedService.erpnextProjectsId,
    ProjectSeedService.workProjectId,
  };

  /// Load persisted toggle into [AppEnvironment] before test bootstrap.
  static Future<void> loadFromSettings() async {
    if (!Hive.isBoxOpen('userSettings')) {
      await Hive.openBox<UserSettingsModel>('userSettings');
    }
    final box = Hive.box<UserSettingsModel>('userSettings');
    final settings = box.get('settings') ?? UserSettingsModel();
    if (box.get('settings') == null) {
      await box.put('settings', settings);
    }
    AppEnvironment.setDevelopmentDataEnabled(settings.developmentDataEnabled);
  }

  /// Persist toggle, update runtime gate, and re-seed when turning on.
  static Future<void> setEnabled(bool enabled) async {
    if (!Hive.isBoxOpen('userSettings')) {
      await Hive.openBox<UserSettingsModel>('userSettings');
    }
    final box = Hive.box<UserSettingsModel>('userSettings');
    final settings = box.get('settings') ?? UserSettingsModel();
    settings.developmentDataEnabled = enabled;
    await box.put('settings', settings);
    AppEnvironment.setDevelopmentDataEnabled(enabled);
    if (enabled) {
      await TestModeBootstrapService.ensureTestData();
      await ProjectSeedService.ensureSampleProjects();
    }
  }

  static bool get showDevData => AppEnvironment.isTest;

  static bool isDevId(String? id) {
    if (id == null || id.isEmpty) return false;
    return id.startsWith('test_') ||
        id.startsWith('test_seed_') ||
        id.startsWith('sample-project-') ||
        sampleProjectIds.contains(id);
  }

  static bool isDevMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    if (metadata['isTestSeed'] == true) return true;
    final source = metadata['source']?.toString() ?? '';
    return source.contains('test_sample') || source == 'test_seed';
  }

  static bool isDevTags(Iterable<String>? tags) {
    if (tags == null) return false;
    for (final tag in tags) {
      if (tag == 'test_seed' || tag.startsWith('test_sample')) {
        return true;
      }
    }
    return false;
  }

  static bool isDevCard(CardModel card) =>
      isDevId(card.id) || isDevMetadata(card.metadata);

  static bool isDevReward(RewardModel reward) =>
      isDevId(reward.id) ||
      isDevMetadata(reward.metadata) ||
      isDevTags(reward.tags);

  /// Filter helper when [showDevData] is false.
  static bool keepVisible({
    String? id,
    Map<String, dynamic>? metadata,
    Iterable<String>? tags,
    String? projectId,
  }) {
    if (showDevData) return true;
    return !isDevId(id) &&
        !isDevId(projectId) &&
        !isDevMetadata(metadata) &&
        !isDevTags(tags);
  }

  static List<T> visibleOnly<T>(
    Iterable<T> items, {
    required String? Function(T item) idOf,
    String? Function(T item)? projectIdOf,
    Map<String, dynamic>? Function(T item)? metadataOf,
    Iterable<String>? Function(T item)? tagsOf,
  }) {
    if (showDevData) return items.toList();
    return items
        .where(
          (item) => keepVisible(
            id: idOf(item),
            projectId: projectIdOf?.call(item),
            metadata: metadataOf?.call(item),
            tags: tagsOf?.call(item),
          ),
        )
        .toList();
  }
}

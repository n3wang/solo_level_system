import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/project_model.dart';

class ProjectSeedService {
  ProjectSeedService._();

  static const String personalProjectsId = 'sample-project-personal';
  static const String erpnextProjectsId = 'sample-project-erpnext';
  static const String workProjectId = 'sample-project-work';

  static const String _projectsBoxName = 'projects';

  /// Legacy sample IDs replaced by the current test defaults.
  static const List<String> _legacySampleIds = [
    'sample-project-deep-work-coding',
    'sample-project-language-sprint',
  ];

  static Future<void> ensureSampleProjects() async {
    if (!AppEnvironment.isTest) return;

    if (!Hive.isBoxOpen(_projectsBoxName)) {
      await Hive.openBox<ProjectModel>(_projectsBoxName);
    }
    final box = Hive.box<ProjectModel>(_projectsBoxName);

    await _removeLegacySamples(box);

    await _upsertSample(
      box,
      ProjectModel(
        id: personalProjectsId,
        name: 'Personal Projects',
        description: 'Work without and with youtube background.',
        color: '#3F51B5',
        iconName: 'code',
        priority: 1,
        targetType: 'daily',
        dailySessionTarget: 2,
        weeklySessionTarget: 10,
        preferredWorkHour: 9,
        activeDays: const [1, 2, 3, 4, 5, 6, 7],
        workDurationMinutes: 10,
        breakDurationMinutes: 15,
        createdAt: DateTime.now(),
        tags: const ['personal'],
      ),
    );

    await _upsertSample(
      box,
      ProjectModel(
        id: erpnextProjectsId,
        name: 'ERPNext Projects',
        description: 'Implementation, some more time for vibe.',
        color: '#00897B',
        iconName: 'business',
        priority: 2,
        targetType: 'daily',
        dailySessionTarget: 2,
        weeklySessionTarget: 10,
        preferredWorkHour: 10,
        activeDays: const [1, 2, 3, 4, 5, 6, 7],
        workDurationMinutes: 8,
        breakDurationMinutes: 17,
        createdAt: DateTime.now(),
        tags: const ['erpnext', 'work'],
      ),
    );

    await _upsertSample(
      box,
      ProjectModel(
        id: workProjectId,
        name: 'Work',
        description: 'General work sessions and day-to-day tasks.',
        color: '#FF9800',
        iconName: 'work',
        priority: 3,
        targetType: 'daily',
        dailySessionTarget: 2,
        weeklySessionTarget: 10,
        preferredWorkHour: 14,
        activeDays: const [1, 2, 3, 4, 5],
        workDurationMinutes: 15,
        breakDurationMinutes: 10,
        createdAt: DateTime.now(),
        tags: const ['work'],
      ),
    );
  }

  static Future<void> _removeLegacySamples(Box<ProjectModel> box) async {
    final toRemove = box.values
        .where((p) => _legacySampleIds.contains(p.id))
        .toList();
    for (final project in toRemove) {
      await project.delete();
    }
  }

  /// Creates sample projects or refreshes their default fields if they already exist.
  static Future<void> _upsertSample(
    Box<ProjectModel> box,
    ProjectModel template,
  ) async {
    ProjectModel? existing;
    for (final value in box.values) {
      if (value.id == template.id) {
        existing = value;
        break;
      }
    }

    if (existing == null) {
      await box.add(template);
      return;
    }

    existing
      ..name = template.name
      ..description = template.description
      ..color = template.color
      ..iconName = template.iconName
      ..priority = template.priority
      ..targetType = template.targetType
      ..dailySessionTarget = template.dailySessionTarget
      ..weeklySessionTarget = template.weeklySessionTarget
      ..preferredWorkHour = template.preferredWorkHour
      ..activeDays = List<int>.from(template.activeDays)
      ..workDurationMinutes = template.workDurationMinutes
      ..breakDurationMinutes = template.breakDurationMinutes
      ..tags = List<String>.from(template.tags);

    await existing.save();
  }
}

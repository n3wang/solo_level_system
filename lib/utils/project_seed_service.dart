import 'package:hive/hive.dart';
import 'package:solo_level_system/models/project_model.dart';

class ProjectSeedService {
  ProjectSeedService._();

  static const String studiesProjectId = 'sample-project-deep-work-coding';
  static const String gamesStudyingProjectId = 'sample-project-language-sprint';

  static const String _projectsBoxName = 'projects';
  static const String _studiesProjectId = studiesProjectId;
  static const String _gamesStudyingProjectId = gamesStudyingProjectId;

  static Future<void> ensureSampleProjects() async {
    if (!Hive.isBoxOpen(_projectsBoxName)) {
      await Hive.openBox<ProjectModel>(_projectsBoxName);
    }
    final box = Hive.box<ProjectModel>(_projectsBoxName);

    await _upsertSample(
      box,
      ProjectModel(
        id: _studiesProjectId,
        name: 'Studies Assignments',
        description: 'Coursework, readings, and assignment blocks.',
        color: '#3F51B5',
        iconName: 'book',
        priority: 3,
        targetType: 'daily',
        dailySessionTarget: 1,
        weeklySessionTarget: 5,
        preferredWorkHour: 9,
        activeDays: const [1, 2, 3, 4, 5],
        workDurationMinutes: 50,
        breakDurationMinutes: 10,
        createdAt: DateTime.now(),
        tags: const ['study', 'assignments'],
      ),
    );

    await _upsertSample(
      box,
      ProjectModel(
        id: _gamesStudyingProjectId,
        name: 'Games and Studying',
        description: 'Short bursts for games, drills, and light study.',
        color: '#FF9800',
        iconName: 'school',
        priority: 2,
        targetType: 'daily',
        dailySessionTarget: 2,
        weeklySessionTarget: 10,
        preferredWorkHour: 19,
        activeDays: const [1, 3, 5, 6],
        workDurationMinutes: 15,
        breakDurationMinutes: 5,
        createdAt: DateTime.now(),
        tags: const ['games', 'study'],
      ),
    );
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

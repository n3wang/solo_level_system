import 'package:hive/hive.dart';
import 'package:solo_level_system/models/project_model.dart';

class ProjectSeedService {
  static const String _projectsBoxName = 'projects';
  static const String _deepWorkProjectId = 'sample-project-deep-work-coding';
  static const String _languageProjectId = 'sample-project-language-sprint';

  static Future<void> ensureSampleProjects() async {
    if (!Hive.isBoxOpen(_projectsBoxName)) {
      await Hive.openBox<ProjectModel>(_projectsBoxName);
    }
    final box = Hive.box<ProjectModel>(_projectsBoxName);
    final allProjects = box.values.toList();

    final hasDeepWork = allProjects.any((p) => p.id == _deepWorkProjectId);
    final hasLanguage = allProjects.any((p) => p.id == _languageProjectId);

    if (!hasDeepWork) {
      await box.add(
        ProjectModel(
          id: _deepWorkProjectId,
          name: 'Deep Work Coding',
          description: 'Long focus blocks for coding and architecture work.',
          color: '#3F51B5',
          iconName: 'code',
          priority: 3,
          targetType: 'daily',
          dailySessionTarget: 4,
          weeklySessionTarget: 18,
          preferredWorkHour: 9,
          activeDays: const [1, 2, 3, 4, 5],
          workDurationMinutes: 50,
          breakDurationMinutes: 10,
          createdAt: DateTime.now(),
          tags: const ['focus', 'coding'],
        ),
      );
    }

    if (!hasLanguage) {
      await box.add(
        ProjectModel(
          id: _languageProjectId,
          name: 'Language Sprint',
          description: 'Short, frequent practice for language consistency.',
          color: '#FF9800',
          iconName: 'school',
          priority: 2,
          targetType: 'weekly',
          dailySessionTarget: 1,
          weeklySessionTarget: 7,
          preferredWorkHour: 19,
          activeDays: const [1, 3, 5, 6],
          workDurationMinutes: 30,
          breakDurationMinutes: 5,
          createdAt: DateTime.now(),
          tags: const ['learning', 'language'],
        ),
      );
    }
  }
}

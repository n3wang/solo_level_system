import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/project_model.dart';

void main() {
  group('Project Durations Tests', () {
    setUp(() async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ProjectModelAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('ProjectModel should have default work and break durations', () {
      final project = ProjectModel(
        id: 'test1',
        name: 'Test Project',
        createdAt: DateTime.now(),
      );

      expect(project.workDurationMinutes, equals(25));
      expect(project.breakDurationMinutes, equals(5));
    });

    test('ProjectModel should allow custom durations', () {
      final project = ProjectModel(
        id: 'test2',
        name: 'Drawing Project',
        createdAt: DateTime.now(),
        workDurationMinutes: 50,
        breakDurationMinutes: 10,
      );

      expect(project.workDurationMinutes, equals(50));
      expect(project.breakDurationMinutes, equals(10));
      expect(project.durationInfo, equals('50m work / 10m break'));
    });

    test('ProjectCreationHelper should create drawing project with correct durations', () {
      final project = ProjectCreationHelper.createDrawingProject(
        name: 'My Drawing',
        description: 'Art project',
      );

      expect(project.workDurationMinutes, equals(50));
      expect(project.breakDurationMinutes, equals(10));
      expect(project.iconName, equals('palette'));
    });

    test('ProjectCreationHelper should create coding project with standard durations', () {
      final project = ProjectCreationHelper.createCodingProject(
        name: 'My Code',
        description: 'Coding project',
      );

      expect(project.workDurationMinutes, equals(25));
      expect(project.breakDurationMinutes, equals(5));
      expect(project.iconName, equals('code'));
    });

    test('ProjectCreationHelper should create study project with longer durations', () {
      final project = ProjectCreationHelper.createStudyProject(
        name: 'My Study',
        description: 'Study project',
      );

      expect(project.workDurationMinutes, equals(45));
      expect(project.breakDurationMinutes, equals(15));
      expect(project.iconName, equals('school'));
    });

    test('Project durations should persist correctly', () async {
      final box = await Hive.openBox<ProjectModel>('testProjects');

      final project = ProjectModel(
        id: 'test3',
        name: 'Custom Project',
        createdAt: DateTime.now(),
        workDurationMinutes: 30,
        breakDurationMinutes: 8,
      );

      await box.put('custom_project', project);
      final retrieved = box.get('custom_project');

      expect(retrieved?.workDurationMinutes, equals(30));
      expect(retrieved?.breakDurationMinutes, equals(8));

      await box.close();
    });

    test('Project should update durations with validation', () async {
      final box = await Hive.openBox<ProjectModel>('testProjectsValidation');

      final project = ProjectModel(
        id: 'test4',
        name: 'Test Project',
        createdAt: DateTime.now(),
      );

      await box.put('test_project', project);

      // Valid updates
      project.updateWorkDuration(45);
      project.updateBreakDuration(10);
      expect(project.workDurationMinutes, equals(45));
      expect(project.breakDurationMinutes, equals(10));

      // Invalid updates should be ignored
      project.updateWorkDuration(0); // Too low
      project.updateWorkDuration(150); // Too high
      project.updateBreakDuration(0); // Too low
      project.updateBreakDuration(70); // Too high

      // Values should remain unchanged
      expect(project.workDurationMinutes, equals(45));
      expect(project.breakDurationMinutes, equals(10));

      await box.close();
    });
  });
}
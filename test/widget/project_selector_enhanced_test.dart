import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/widgets/pomodoro/project_selector_widget.dart';

void main() {
  group('Enhanced Project Selector Tests', () {
    late List<ProjectModel> testProjects;

    setUp(() async {
      await setUpTestHive();
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ProjectModelAdapter());
      }

      // Create test projects with different completion states
      final today = DateTime.now().weekday;
      testProjects = [
        ProjectModel(
          id: '1',
          name: 'Drawing',
          createdAt: DateTime.now(),
          workDurationMinutes: 50,
          breakDurationMinutes: 10,
          dailySessionTarget: 3,
          activeDays: [today], // Active today
          dailyStats: {
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}': 1,
          },
        ),
        ProjectModel(
          id: '2',
          name: 'Coding',
          createdAt: DateTime.now(),
          workDurationMinutes: 25,
          breakDurationMinutes: 5,
          dailySessionTarget: 4,
          activeDays: [today], // Active today
          dailyStats: {
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}': 4,
          },
        ),
        ProjectModel(
          id: '3',
          name: 'Study',
          createdAt: DateTime.now(),
          workDurationMinutes: 45,
          breakDurationMinutes: 15,
          dailySessionTarget: 2,
          activeDays: [today], // Active today
          dailyStats: {
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}': 0,
          },
        ),
      ];
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('should show all projects when no project selected', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: null,
              onProjectSelected: (project) {},
              isRunning: false,
              canSubmitLog: false,
            ),
          ),
        ),
      );

      // Should show all projects
      expect(find.text('Drawing'), findsOneWidget);
      expect(find.text('Coding'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);

      // Should show remaining work text
      expect(find.text('2 left'), findsNWidgets(2)); // Drawing: 3 target - 1 done = 2 left, Study: 2 target - 0 done = 2 left
      expect(find.text('Complete ✓'), findsOneWidget); // Coding: 4 target - 4 done = complete
    });

    testWidgets('should hide selector during active work session', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: testProjects[0],
              onProjectSelected: (project) {},
              isRunning: true,
              canSubmitLog: false, // Active work session
            ),
          ),
        ),
      );

      // Should be hidden during active work
      expect(find.text('Drawing'), findsNothing);
      expect(find.text('Coding'), findsNothing);
      expect(find.text('Study'), findsNothing);
    });

    testWidgets('should show selector during break or submission', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: testProjects[0],
              onProjectSelected: (project) {},
              isRunning: true,
              canSubmitLog: true, // Session complete - can submit
            ),
          ),
        ),
      );

      // Should show during submission phase
      expect(find.text('Drawing'), findsOneWidget);
    });

    testWidgets('should show only selected project with toggle option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: testProjects[0], // Drawing selected
              onProjectSelected: (project) {},
              isRunning: false,
              canSubmitLog: false,
            ),
          ),
        ),
      );

      // Should show only selected project initially
      expect(find.text('Drawing'), findsOneWidget);
      expect(find.text('Coding'), findsNothing);
      expect(find.text('Study'), findsNothing);

      // Should show toggle button
      expect(find.text('Show all projects'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('should expand to show all projects when toggle tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: testProjects[0],
              onProjectSelected: (project) {},
              isRunning: false,
              canSubmitLog: false,
            ),
          ),
        ),
      );

      // Tap the toggle button to show all projects
      await tester.tap(find.text('Show all projects'));
      await tester.pump();

      // Should now show all projects
      expect(find.text('Drawing'), findsOneWidget);
      expect(find.text('Coding'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);

      // Toggle button should change
      expect(find.text('Show less'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('should show duration info during running sessions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: testProjects[0],
              onProjectSelected: (project) {},
              isRunning: true,
              canSubmitLog: true, // Can submit - show duration instead of remaining
            ),
          ),
        ),
      );

      // Should show duration info instead of remaining work
      expect(find.text('50/10m'), findsOneWidget); // Drawing project duration
    });

    testWidgets('should call onProjectSelected when project tapped', (WidgetTester tester) async {
      ProjectModel? selectedProject;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSelectorWidget(
              projects: testProjects,
              selectedProject: null,
              onProjectSelected: (project) {
                selectedProject = project;
              },
              isRunning: false,
              canSubmitLog: false,
            ),
          ),
        ),
      );

      // Tap on Drawing project
      await tester.tap(find.text('Drawing'));

      expect(selectedProject?.name, equals('Drawing'));
    });
  });
}
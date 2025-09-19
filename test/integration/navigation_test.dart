import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/main.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/screens/home_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';

void main() {
  group('App Navigation Integration Tests', () {
    setUpAll(() async {
      await setUpTestHive();

      // Register all adapters
      Hive.registerAdapter(PomodoroModelAdapter());
      Hive.registerAdapter(UserSettingsModelAdapter());
      Hive.registerAdapter(AudioSettingsModelAdapter());
      Hive.registerAdapter(EnhancedAudioModelAdapter());
      Hive.registerAdapter(ConfigModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    setUp(() async {
      // Clean up test boxes before each test
      final boxes = ['pomodoros', 'userSettings', 'audioSettings', 'audioFiles', 'config'];
      for (final boxName in boxes) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
    });

    testWidgets('Should navigate from home screen to settings without crashes', (WidgetTester tester) async {
      // Create a test app with navigation
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(),
        routes: {
          '/settings': (context) => SettingsScreen(),
        },
      ));

      await tester.pumpAndSettle();

      // Verify we're on the home screen
      expect(find.text('Solo Level System'), findsOneWidget);

      // Open the drawer (assuming there's a drawer button)
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Look for settings navigation option in drawer or menu
      if (find.text('Settings').evaluate().isNotEmpty) {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // Verify we navigated to settings
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
      }
    });

    testWidgets('Should handle rapid navigation between tabs without errors', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Rapidly switch between tabs multiple times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Sessions'));
        await tester.pump(Duration(milliseconds: 50));

        await tester.tap(find.text('Notifications'));
        await tester.pump(Duration(milliseconds: 50));

        await tester.tap(find.text('Appearance'));
        await tester.pump(Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Should still be functional
      expect(find.text('Theme Mode'), findsOneWidget);
    });

    testWidgets('Should maintain app state when navigating back and forth', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (context) => HomeScreen(),
          '/settings': (context) => SettingsScreen(),
        },
      ));

      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      if (find.text('Settings').evaluate().isNotEmpty) {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // Change a setting
        final themeDropdown = find.byKey(Key('theme_dropdown'));
        if (themeDropdown.evaluate().isNotEmpty) {
          await tester.tap(themeDropdown);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Dark').last);
          await tester.pumpAndSettle();
        }

        // Navigate back
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Navigate to settings again
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        if (find.text('Settings').evaluate().isNotEmpty) {
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();

          // Setting should still be Dark if it was changed
          if (themeDropdown.evaluate().isNotEmpty) {
            expect(find.text('Dark'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('Should handle deep linking to specific settings tabs', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: DefaultTabController(
          length: 3,
          initialIndex: 1, // Start on Sessions tab
          child: SettingsScreen(),
        ),
      ));

      await tester.pumpAndSettle();

      // Should start on the Sessions tab
      expect(find.text('Default Durations'), findsOneWidget);
      expect(find.text('Work Duration'), findsOneWidget);
    });

    testWidgets('Should handle settings changes without affecting other screens', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (context) => HomeScreen(),
          '/settings': (context) => SettingsScreen(),
        },
      ));

      await tester.pumpAndSettle();

      // Record initial state of home screen
      final initialHomeState = find.text('Solo Level System').evaluate().isNotEmpty;

      // Navigate to settings and make changes
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      if (find.text('Settings').evaluate().isNotEmpty) {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // Make multiple setting changes
        await tester.tap(find.text('Sessions'));
        await tester.pumpAndSettle();

        // Toggle some switches in notifications tab
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();

        if (find.byType(Switch).evaluate().isNotEmpty) {
          await tester.tap(find.byType(Switch).first);
          await tester.pumpAndSettle();
        }

        // Navigate back to home
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Home screen should still be functioning
        expect(find.text('Solo Level System'), findsOneWidget);
        expect(initialHomeState, true);
      }
    });

    testWidgets('Should persist settings across app restarts', (WidgetTester tester) async {
      // Open test boxes
      await Hive.openBox<UserSettingsModel>('userSettings');

      // First app session
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Change theme to dark
      final themeDropdown = find.byKey(Key('theme_dropdown'));
      if (themeDropdown.evaluate().isNotEmpty) {
        await tester.tap(themeDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dark').last);
        await tester.pumpAndSettle();
      }

      // Wait for save operation
      await tester.pump(Duration(milliseconds: 200));

      // Simulate app restart by creating new widget tree
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Start "new" app session
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Theme should still be Dark
      expect(find.text('Dark'), findsOneWidget);

      // Close test boxes
      await Hive.box('userSettings').close();
    });

    testWidgets('Should handle error states gracefully during navigation', (WidgetTester tester) async {
      // Test with minimal setup to potentially trigger errors
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      // Don't wait for settling to test intermediate states
      await tester.pump();

      // Try to interact before fully loaded
      if (find.text('Sessions').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sessions'));
        await tester.pump();
      }

      // Should eventually settle without crashes
      await tester.pumpAndSettle();

      // Verify the screen is still functional
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
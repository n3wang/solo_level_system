import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    setUpAll(() async {
      await setUpTestHive();
      Hive.registerAdapter(UserSettingsModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    setUp(() async {
      // Clean up any existing test boxes
      if (Hive.isBoxOpen('userSettings')) {
        await Hive.box('userSettings').clear();
      }
    });

    testWidgets('Settings screen should load without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Verify the screen elements are present
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('Should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      // Initially should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Should display default settings values', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Check for default theme value
      expect(find.text('System'), findsOneWidget);

      // Check for default color value
      expect(find.text('Red'), findsOneWidget);

      // Navigate to Sessions tab
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();

      // Check default work duration (25 minutes)
      expect(find.text('25 minutes'), findsOneWidget);

      // Check default break duration (5 minutes)
      expect(find.text('5 minutes'), findsOneWidget);
    });

    testWidgets('Should be able to change theme setting', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Find and tap on theme dropdown
      final themeDropdown = find.byKey(Key('theme_dropdown')).first;
      await tester.tap(themeDropdown);
      await tester.pumpAndSettle();

      // Select dark theme
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      // Verify the setting changed
      // The dropdown should now show "Dark" as selected
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('Should be able to change work duration with slider', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Navigate to Sessions tab
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();

      // Find the work duration slider
      final slider = find.byType(Slider).first;

      // Move slider to increase work duration
      await tester.drag(slider, Offset(50, 0));
      await tester.pumpAndSettle();

      // The minutes value should have changed from 25
      expect(find.text('25 minutes'), findsNothing);
    });

    testWidgets('Should be able to toggle notification switches', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Navigate to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Find and toggle notification switch
      final notificationSwitch = find.byType(Switch).first;
      final initialValue = tester.widget<Switch>(notificationSwitch).value;

      await tester.tap(notificationSwitch);
      await tester.pumpAndSettle();

      // Verify the switch toggled
      final newValue = tester.widget<Switch>(notificationSwitch).value;
      expect(newValue, !initialValue);
    });

    testWidgets('Should persist settings when changed', (WidgetTester tester) async {
      // Open a Hive box for testing
      final box = await Hive.openBox<UserSettingsModel>('userSettings');

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Change primary color
      final colorDropdown = find.byKey(Key('color_dropdown')).first;
      await tester.tap(colorDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue').last);
      await tester.pumpAndSettle();

      // Wait a bit for the async save operation
      await tester.pump(Duration(milliseconds: 100));

      // Verify settings were saved to Hive
      final savedSettings = box.get('settings');
      expect(savedSettings, isNotNull);
      expect(savedSettings!.primaryColor, equals('blue'));

      await box.close();
    });

    testWidgets('Should handle navigation between tabs without errors', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Navigate through all tabs
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();
      expect(find.text('Default Durations'), findsOneWidget);

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Enable Notifications'), findsOneWidget);

      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Theme Mode'), findsOneWidget);

      // No errors should occur during navigation
    });

    testWidgets('Should maintain scroll position in tabs', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pumpAndSettle();

      // Navigate to Sessions tab
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();

      // Scroll down
      await tester.drag(find.byType(ListView), Offset(0, -300));
      await tester.pumpAndSettle();

      // Switch to another tab and back
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();

      // Content should still be visible (scroll position maintained)
      expect(find.text('Default Durations'), findsOneWidget);
    });
  });
}
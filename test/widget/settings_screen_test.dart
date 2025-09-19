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

    testWidgets('Settings screen should load basic UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      // Just pump once and check for basic elements
      await tester.pump();

      // Verify basic screen structure loads
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Settings screen should show tabs', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));

      // Just check for TabBar which should always be present
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Settings screen should handle loading state', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      // Just check that the screen initializes without crashing
      await tester.pump();

      // Should show either loading indicator or the main content
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasTabBarView = find.byType(TabBarView).evaluate().isNotEmpty;

      // One of these should be true
      expect(hasLoading || hasTabBarView, isTrue);
    });
  });
}
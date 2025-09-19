import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/screens/settings_screen.dart';

void main() {
  group('Basic Integration Tests', () {
    setUpAll(() async {
      await setUpTestHive();
      Hive.registerAdapter(UserSettingsModelAdapter());
    });

    tearDownAll(() async {
      await tearDownTestHive();
    });

    testWidgets('SettingsScreen should load without crashes', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(),
      ));

      await tester.pump();

      // Basic smoke test - just verify it doesn't crash
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
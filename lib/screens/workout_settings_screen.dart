// lib/screens/workout_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';

class WorkoutSettingsScreen extends StatelessWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColorPalette.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'Timed Workouts',
            children: [
              ListTile(
                leading: Icon(Icons.timer),
                title: Text('Manage Timed Workouts'),
                subtitle: Text('Create and edit timed workout routines'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to timed workouts management
                  // TODO: Implement timed workouts management screen
                },
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Exercise Settings',
            children: [
              ListTile(
                leading: Icon(Icons.fitness_center),
                title: Text('Default Exercise Settings'),
                subtitle: Text('Configure default values for new exercises'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement exercise default settings
                },
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Workout Preferences',
            children: [
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Rest Timer'),
                subtitle: Text('Configure rest timer settings'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement rest timer settings
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColorPalette.textColor,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/home_screen.dart';
import 'package:solo_level_system/screens/analytics_screen.dart';
import 'package:solo_level_system/screens/workout_mode_screen.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

class MainNavigationScreen extends StatefulWidget {
  final Function(UserSettingsModel)? onSettingsChanged;

  const MainNavigationScreen({Key? key, this.onSettingsChanged})
    : super(key: key);
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onSettingsChanged: () => widget.onSettingsChanged?.call),
      AnalyticsScreen(),
      WorkoutModeScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            activeIcon: Icon(Icons.timer, size: 28),
            label: 'Focus',
            tooltip: 'Pomodoro Timer & Focus Sessions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            activeIcon: Icon(Icons.analytics, size: 28),
            label: 'Analytics',
            tooltip: 'Progress & Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            activeIcon: Icon(Icons.fitness_center, size: 28),
            label: 'Workout',
            tooltip: 'Workout Routines & Tracking',
          ),
        ],
      ),
    );
  }
}

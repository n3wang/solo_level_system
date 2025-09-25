// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/home_screen.dart';
import 'package:solo_level_system/screens/analytics_screen.dart';
import 'package:solo_level_system/screens/workout_mode_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
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
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.grey[700],
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            activeIcon: Icon(Icons.timer),
            label: '',
            tooltip: 'Pomodoro Timer & Focus Sessions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: '',
            tooltip: 'Progress & Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: '',
            tooltip: 'Workout Routines & Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '',
            tooltip: 'App Settings & Configuration',
          ),
        ],
      ),
    );
  }
}

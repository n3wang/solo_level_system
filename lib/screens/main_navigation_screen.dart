// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/home_screen.dart';
import 'package:solo_level_system/screens/analytics_screen.dart';
import 'package:solo_level_system/screens/rewards_management_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
import 'package:solo_level_system/screens/workout_screen.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

class MainNavigationScreen extends StatefulWidget {
  final Function(UserSettingsModel)? onSettingsChanged;

  const MainNavigationScreen({super.key, this.onSettingsChanged});
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
      HomeScreen(onSettingsChanged: () => _notifySettingsChanged()),
      AnalyticsScreen(),
      WorkoutScreen(),
      RewardsManagementScreen(),
      SettingsScreen(),
    ];
  }

  void _notifySettingsChanged() {
    widget.onSettingsChanged?.call(UserSettingsModel());
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          final bool comingFromSettings = _currentIndex == 4;
          setState(() {
            _currentIndex = index;
          });

          // If switching to home screen from settings, reload settings
          if (comingFromSettings && index == 0) {
            _notifySettingsChanged();
          }
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
            tooltip: 'Workout & Exercise Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard),
            label: '',
            tooltip: 'Rewards & Points',
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

// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/screens/home_screen.dart';
import 'package:solo_level_system/screens/analytics_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
import 'package:solo_level_system/screens/workout_screen.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/utils/timer_controller.dart';

class MainNavigationScreen extends StatefulWidget {
  final Function(UserSettingsModel)? onSettingsChanged;

  const MainNavigationScreen({super.key, this.onSettingsChanged});
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _timerController = TimerController();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _timerController.addListener(_onTimerStateChanged);
    _screens = [
      HomeScreen(onSettingsChanged: () => _notifySettingsChanged()),
      AnalyticsScreen(),
      WorkoutScreen(),
      SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    _timerController.removeListener(_onTimerStateChanged);
    super.dispose();
  }

  void _onTimerStateChanged() {
    if (!mounted || _currentIndex != 0) return;
    setState(() {});
  }

  void _notifySettingsChanged() {
    widget.onSettingsChanged?.call(UserSettingsModel());
  }

  bool get _colorBackgroundBySessionMode {
    try {
      if (!Hive.isBoxOpen('userSettings')) return false;
      return Hive.box<UserSettingsModel>('userSettings')
              .get('settings')
              ?.colorBackgroundBySessionMode ??
          false;
    } catch (_) {
      return false;
    }
  }

  Color? get _pomodoroScaffoldBackground {
    if (_currentIndex != 0) return null;
    return AppColorPalette.sessionModeBackground(
      enabled: _colorBackgroundBySessionMode,
      onBreak: _timerController.onBreak,
      brightness: Theme.of(context).brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pomodoroScaffoldBackground,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: AppColorPalette.grey700,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          final bool comingFromSettings = _currentIndex == 3;
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

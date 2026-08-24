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
  /// Above this window width (desktop full-app mode), the shell swaps the
  /// mobile [BottomNavigationBar] for a [NavigationRail] instead. Below it,
  /// on every platform, behavior is unchanged from the mobile layout.
  static const double _desktopRailBreakpoint = 800;

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
      return Hive.box<UserSettingsModel>(
            'userSettings',
          ).get('settings')?.colorBackgroundBySessionMode ??
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

  void _onDestinationSelected(int index) {
    final bool comingFromSettings = _currentIndex == 3;
    setState(() {
      _currentIndex = index;
    });

    // If switching to home screen from settings, reload settings
    if (comingFromSettings && index == 0) {
      _notifySettingsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _desktopRailBreakpoint;
        final content = IndexedStack(index: _currentIndex, children: _screens);
        return Scaffold(
          backgroundColor: _pomodoroScaffoldBackground,
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: IconThemeData(
                        color: Theme.of(context).primaryColor,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: AppColorPalette.grey700,
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.timer_outlined),
                          selectedIcon: Icon(Icons.timer),
                          label: Text('Timer'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.analytics_outlined),
                          selectedIcon: Icon(Icons.analytics),
                          label: Text('Stats'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.fitness_center_outlined),
                          selectedIcon: Icon(Icons.fitness_center),
                          label: Text('Workout'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : BottomNavigationBar(
                  currentIndex: _currentIndex,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor: AppColorPalette.grey700,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  onTap: _onDestinationSelected,
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
      },
    );
  }
}

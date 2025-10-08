// lib/screens/workout_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/workout_routines_screen.dart';
import 'package:solo_level_system/screens/workout_exercises_screen.dart';
import 'package:solo_level_system/screens/workout_quick_start_screen.dart';
import 'package:solo_level_system/screens/workout_history_screen.dart';
import 'package:solo_level_system/models/workout_session_model.dart';

class WorkoutNavigationScreen extends StatefulWidget {
  @override
  _WorkoutNavigationScreenState createState() => _WorkoutNavigationScreenState();
}

class _WorkoutNavigationScreenState extends State<WorkoutNavigationScreen> {
  int _currentIndex = 0;
  WorkoutSessionModel? _activeSession;

  late final List<Widget> _screens;
  late final List<WorkoutNavigationItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _initializeNavigationItems();
  }

  void _initializeScreens() {
    _screens = [
      WorkoutRoutinesScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
        activeSession: _activeSession,
      ),
      WorkoutExercisesScreen(),
      WorkoutQuickStartScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
      ),
      WorkoutHistoryScreen(),
    ];
  }

  void _initializeNavigationItems() {
    _navigationItems = [
      WorkoutNavigationItem(
        icon: Icons.list_outlined,
        activeIcon: Icons.list,
        label: 'Routines',
        tooltip: 'Workout Routines & Programs',
      ),
      WorkoutNavigationItem(
        icon: Icons.fitness_center_outlined,
        activeIcon: Icons.fitness_center,
        label: 'Exercises',
        tooltip: 'Exercise Library & Database',
      ),
      WorkoutNavigationItem(
        icon: Icons.play_circle_outline,
        activeIcon: Icons.play_circle,
        label: 'Quick Start',
        tooltip: 'Start Workout Session',
      ),
      WorkoutNavigationItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'History',
        tooltip: 'Workout History & Progress',
      ),
    ];
  }

  void _handleActiveSessionChanged(WorkoutSessionModel? session) {
    setState(() {
      _activeSession = session;
    });
    _updateScreensWithActiveSession();
  }

  void _updateScreensWithActiveSession() {
    setState(() {
      _screens[0] = WorkoutRoutinesScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
        activeSession: _activeSession,
      );
      _screens[2] = WorkoutQuickStartScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 8,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: _navigationItems.map((item) {
            final isSelected = _currentIndex == _navigationItems.indexOf(item);
            return BottomNavigationBarItem(
              icon: Icon(isSelected ? item.activeIcon : item.icon),
              label: item.label,
              tooltip: item.tooltip,
            );
          }).toList(),
        ),
      ),
      floatingActionButton: _activeSession != null ? _buildActiveSessionFAB() : null,
    );
  }

  Widget _buildActiveSessionFAB() {
    return FloatingActionButton.extended(
      heroTag: "workout_active_session",
      onPressed: _navigateToActiveSession,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      icon: Icon(Icons.fitness_center),
      label: Text('Active Workout'),
    );
  }

  void _navigateToActiveSession() {
    if (_activeSession != null) {
      // TODO: Navigate to active workout session screen
      // This will be implemented when integrating with existing active session logic
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to active session: ${_activeSession!.id}'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class WorkoutNavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String tooltip;

  const WorkoutNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tooltip,
  });
}
// lib/screens/workout_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/workout_sets_screen.dart';
import 'package:solo_level_system/screens/workout_exercises_screen.dart';
import 'package:solo_level_system/screens/workout_quick_start_screen.dart';
import 'package:solo_level_system/screens/workout_history_screen.dart';
import 'package:solo_level_system/screens/motivational_cards_screen.dart';
import 'package:solo_level_system/models/workout_session_model.dart';

class WorkoutNavigationScreen extends StatefulWidget {
  const WorkoutNavigationScreen({super.key});

  @override
  _WorkoutNavigationScreenState createState() =>
      _WorkoutNavigationScreenState();
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
      WorkoutSetsScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
        activeSession: _activeSession,
      ),
      WorkoutExercisesScreen(),
      WorkoutQuickStartScreen(
        onActiveSessionChanged: _handleActiveSessionChanged,
      ),
      WorkoutHistoryScreen(),
      MotivationalCardsScreen(),
    ];
  }

  void _initializeNavigationItems() {
    _navigationItems = [
      WorkoutNavigationItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view,
        label: 'Sets',
        tooltip: 'Workout Sets & Organization',
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
      WorkoutNavigationItem(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome,
        label: 'Motivation',
        tooltip: 'Motivational Cards & Inspiration',
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
      _screens[0] = WorkoutSetsScreen(
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
      body: Column(
        children: [
          _buildTopNavigationBar(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      floatingActionButton: _activeSession != null
          ? _buildActiveSessionFAB()
          : null,
    );
  }

  Widget _buildTopNavigationBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.only(top: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha:0.2), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _navigationItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildNavigationButton(index, item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(int index, WorkoutNavigationItem item) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Tooltip(
        message: item.tooltip,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          child: Container(
            height: 60,
            margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withValues(alpha:0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withValues(alpha:0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                size: 28,
              ),
            ),
          ),
        ),
      ),
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

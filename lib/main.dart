import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants/color_palette.dart';
import 'screens/main_navigation_screen.dart';
import 'models/pomodoro_model.dart';
import 'models/user_settings_model.dart';
import 'models/audio_settings_model.dart';
import 'models/enhanced_audio_model.dart';
import 'models/config_model.dart';
import 'models/exercise_model.dart';
import 'models/workout_set_model.dart';
import 'models/workout_routine_model.dart';
import 'models/workout_session_model.dart';
import 'models/workout_set_category_model.dart';
import 'models/habit_tracker_model.dart';
import 'models/project_model.dart';
import 'models/user_progress_model.dart';
import 'models/reward_model.dart';
import 'models/motivational_card_model.dart';
import 'utils/default_workouts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();

    // Register all Hive adapters
    Hive.registerAdapter(PomodoroModelAdapter());
    Hive.registerAdapter(UserSettingsModelAdapter());
    Hive.registerAdapter(AudioSettingsModelAdapter());
    Hive.registerAdapter(EnhancedAudioModelAdapter());
    Hive.registerAdapter(ConfigModelAdapter());

    // Register workout-related adapters
    Hive.registerAdapter(ExerciseModelAdapter());
    Hive.registerAdapter(WorkoutSetModelAdapter());
    Hive.registerAdapter(WorkoutRoutineModelAdapter());
    Hive.registerAdapter(WorkoutSessionModelAdapter());
    Hive.registerAdapter(WorkoutSetCategoryModelAdapter());
    Hive.registerAdapter(HabitTrackerModelAdapter());
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(UserProgressModelAdapter());
    Hive.registerAdapter(RewardModelAdapter());
    Hive.registerAdapter(MotivationalCardModelAdapter());

    // Open all Hive boxes with detailed logging
    print('Opening Hive boxes...');

    // Open core boxes
    await Hive.openBox<PomodoroModel>('pomodoros');
    print('✓ Opened pomodoros box');

    await Hive.openBox<UserSettingsModel>('userSettings');
    print('✓ Opened userSettings box');

    await Hive.openBox<AudioSettingsModel>('audioSettings');
    print('✓ Opened audioSettings box');

    await Hive.openBox<EnhancedAudioModel>('audioFiles');
    print('✓ Opened audioFiles box');

    // Config box - handle potential TypeId change
    try {
      await Hive.openBox<ConfigModel>('config');
      print('✓ Opened config box');
    } catch (e) {
      print('⚠️ Error opening config box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('config');
      } catch (deleteError) {
        print(
          'Note: Could not delete config box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<ConfigModel>('config');
      print('✓ Recreated config box');
    }

    // Open workout-related boxes (with error recovery)
    try {
      await Hive.openBox<ExerciseModel>('exercises');
      print('✓ Opened exercises box');
    } catch (e) {
      print('⚠️ Error opening exercises box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('exercises');
      } catch (deleteError) {
        print(
          'Note: Could not delete exercises box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<ExerciseModel>('exercises');
      print('✓ Recreated exercises box');
    }

    try {
      await Hive.openBox<WorkoutRoutineModel>('workoutRoutines');
      print('✓ Opened workoutRoutines box');
    } catch (e) {
      print(
        '⚠️ Error opening workoutRoutines box, clearing and recreating: $e',
      );
      try {
        await Hive.deleteBoxFromDisk('workoutRoutines');
      } catch (deleteError) {
        print(
          'Note: Could not delete workoutRoutines box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<WorkoutRoutineModel>('workoutRoutines');
      print('✓ Recreated workoutRoutines box');
    }

    try {
      await Hive.openBox<WorkoutSessionModel>('workoutSessions');
      print('✓ Opened workoutSessions box');
    } catch (e) {
      print(
        '⚠️ Error opening workoutSessions box, clearing and recreating: $e',
      );
      try {
        await Hive.deleteBoxFromDisk('workoutSessions');
      } catch (deleteError) {
        print(
          'Note: Could not delete workoutSessions box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<WorkoutSessionModel>('workoutSessions');
      print('✓ Recreated workoutSessions box');
    }

    try {
      await Hive.openBox<WorkoutSetCategoryModel>('workoutSetCategories');
      print('✓ Opened workoutSetCategories box');
    } catch (e) {
      print(
        '⚠️ Error opening workoutSetCategories box, clearing and recreating: $e',
      );
      try {
        await Hive.deleteBoxFromDisk('workoutSetCategories');
      } catch (deleteError) {
        print(
          'Note: Could not delete workoutSetCategories box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<WorkoutSetCategoryModel>('workoutSetCategories');
      print('✓ Recreated workoutSetCategories box');
    }

    try {
      await Hive.openBox<HabitTrackerModel>('habits');
      print('✓ Opened habits box');
    } catch (e) {
      print('⚠️ Error opening habits box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('habits');
      } catch (deleteError) {
        print(
          'Note: Could not delete habits box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<HabitTrackerModel>('habits');
      print('✓ Recreated habits box');
    }

    try {
      await Hive.openBox<ProjectModel>('projects');
      print('✓ Opened projects box');
    } catch (e) {
      print('⚠️ Error opening projects box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('projects');
      } catch (deleteError) {
        print(
          'Note: Could not delete projects box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<ProjectModel>('projects');
      print('✓ Recreated projects box');
    }

    try {
      await Hive.openBox<UserProgressModel>('userProgress');
      print('✓ Opened userProgress box');
    } catch (e) {
      print('⚠️ Error opening userProgress box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('userProgress');
      } catch (deleteError) {
        print(
          'Note: Could not delete userProgress box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<UserProgressModel>('userProgress');
      print('✓ Recreated userProgress box');
    }

    try {
      await Hive.openBox<RewardModel>('rewards');
      print('✓ Opened rewards box');
    } catch (e) {
      print('⚠️ Error opening rewards box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('rewards');
      } catch (deleteError) {
        print(
          'Note: Could not delete rewards box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<RewardModel>('rewards');
      print('✓ Recreated rewards box');
    }

    try {
      await Hive.openBox<MotivationalCardModel>('motivationalCards');
      print('✓ Opened motivationalCards box');
    } catch (e) {
      print(
        '⚠️ Error opening motivationalCards box, clearing and recreating: $e',
      );
      try {
        await Hive.deleteBoxFromDisk('motivationalCards');
      } catch (deleteError) {
        print(
          'Note: Could not delete motivationalCards box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<MotivationalCardModel>('motivationalCards');
      print('✓ Recreated motivationalCards box');
    }

    print('All Hive boxes opened successfully');

    // Initialize default workouts on first install
    try {
      await DefaultWorkoutsService.initializeDefaultWorkouts();
    } catch (e) {
      print('⚠️ Error initializing default workouts: $e');
      // Continue app startup even if default workouts fail
    }

    runApp(MyApp());
  } catch (e, stackTrace) {
    print('❌ Critical Hive initialization error: $e');
    print('Stack trace: $stackTrace');

    // Still run the app but with error state
    runApp(MyApp(initializationError: e.toString()));
  }
}

class MyApp extends StatefulWidget {
  final String? initializationError;

  const MyApp({super.key, this.initializationError});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UserSettingsModel userSettings = UserSettingsModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final box = Hive.box<UserSettingsModel>('userSettings');
      userSettings = box.get('settings') ?? UserSettingsModel();
      
      // Migrate old palette names
      if (userSettings.colorPalette == 'original' || userSettings.colorPalette == 'default') {
        userSettings.colorPalette = 'creative';
        await box.put('settings', userSettings);
      } else if (!['grayscale', 'creative', 'pastel'].contains(userSettings.colorPalette)) {
        // If palette doesn't exist, default to creative
        userSettings.colorPalette = 'creative';
        await box.put('settings', userSettings);
      }
      
      // Apply saved palette
      AppColorPalette.setActivePalette(userSettings.colorPalette);
    } catch (e) {
      print('Error loading user settings in main: $e');
      userSettings = UserSettingsModel();
      AppColorPalette.setActivePalette('default');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSettingsChanged() {
    _loadUserSettings();
  }

  MaterialColor _getPrimaryMaterialColor(String colorName) {
    switch (colorName) {
      case 'blue':
        return AppColorPalette.materialColor2; // Blue
      case 'green':
        return AppColorPalette.materialColor3; // Green
      case 'purple':
        return AppColorPalette.materialColor1; // Purple
      case 'orange':
        return AppColorPalette.materialColor4; // Orange
      case 'red':
      default:
        return AppColorPalette.materialColor5; // Red
    }
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if initialization failed
    if (widget.initializationError != null) {
      return MaterialApp(
        title: 'Solo Level System - Error',
        home: Scaffold(
          appBar: AppBar(title: Text('Initialization Error')),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: AppColorPalette.error),
                  SizedBox(height: 16),
                  Text(
                    'Failed to initialize database',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.initializationError!,
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => MyApp()),
                      );
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final primaryColor = _getPrimaryMaterialColor(userSettings.primaryColor);

    return MaterialApp(
      title: 'Solo Level System',
      theme: ThemeData(
        primarySwatch: primaryColor,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: primaryColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: _getThemeMode(userSettings.theme),
      home: MainNavigationScreen(
        onSettingsChanged: (settings) => _onSettingsChanged(),
      ),
    );
  }
}

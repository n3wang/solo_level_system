import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/app_environment.dart';
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
import 'models/motivation_item_model.dart';
import 'models/motivation_points_transaction_model.dart';
import 'models/timed_workout_model.dart';
import 'models/long_break_queue_item_model.dart';
import 'utils/default_workouts_service.dart';
import 'utils/test_mode_bootstrap_service.dart';
import 'utils/programs_service.dart';
import 'utils/palette_notifier.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

const String _noisyWebWindowAssertPath =
    'org-dartlang-sdk:///lib/_engine/engine/window.dart:99:12';
const String _noisyWebWindowAssertPrefix =
    'Another exception was thrown: Assertion failed:';

bool _isNoisyWebEngineWindowAssertion(String text) {
  return kIsWeb && text.contains(_noisyWebWindowAssertPath);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('App environment: ${AppEnvironment.name} (test=${AppEnvironment.isTest})');

  // Suppress a known noisy Flutter web engine assertion spam in debug logs.
  // Keep all other framework/runtime errors visible.
  final defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (kIsWeb &&
        message != null &&
        (message.contains(_noisyWebWindowAssertPath) ||
            message.trim() == _noisyWebWindowAssertPrefix)) {
      return;
    }
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    final stackTraceText = details.stack?.toString() ?? '';
    final exceptionText = details.exceptionAsString();
    final libraryText = details.library ?? '';
    if (_isNoisyWebEngineWindowAssertion(
      '$stackTraceText\n$exceptionText\n$libraryText',
    )) {
      return;
    }
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (_isNoisyWebEngineWindowAssertion('$error\n$stack')) {
      return true;
    }
    return false;
  };

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
    Hive.registerAdapter(MotivationItemModelAdapter());
    Hive.registerAdapter(MotivationPointsTransactionModelAdapter());
    Hive.registerAdapter(TimedWorkoutItemAdapter());
    Hive.registerAdapter(TimedWorkoutModelAdapter());
    Hive.registerAdapter(LongBreakQueueItemModelAdapter());

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

    // App initialization flags box (untyped, for simple boolean flags)
    await Hive.openBox('app_init_flags');
    print('✓ Opened app_init_flags box');

    try {
      await Hive.openBox<LongBreakQueueItemModel>('longBreakQueue');
      print('✓ Opened longBreakQueue box');
    } catch (e) {
      print('⚠️ Error opening longBreakQueue box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('longBreakQueue');
      } catch (deleteError) {
        print(
          'Note: Could not delete longBreakQueue box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<LongBreakQueueItemModel>('longBreakQueue');
      print('✓ Recreated longBreakQueue box');
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
      await Hive.openBox<TimedWorkoutModel>('timedWorkouts');
      print('✓ Opened timedWorkouts box');
    } catch (e) {
      print('⚠️ Error opening timedWorkouts box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('timedWorkouts');
      } catch (deleteError) {
        print(
          'Note: Could not delete timedWorkouts box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<TimedWorkoutModel>('timedWorkouts');
      print('✓ Recreated timedWorkouts box');
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

    try {
      await Hive.openBox<MotivationItemModel>('motivationItems');
      print('✓ Opened motivationItems box');
    } catch (e) {
      print('⚠️ Error opening motivationItems box, clearing and recreating: $e');
      try {
        await Hive.deleteBoxFromDisk('motivationItems');
      } catch (deleteError) {
        print(
          'Note: Could not delete motivationItems box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<MotivationItemModel>('motivationItems');
      print('✓ Recreated motivationItems box');
    }

    try {
      await Hive.openBox<MotivationPointsTransactionModel>(
        'motivationPointsTransactions',
      );
      print('✓ Opened motivationPointsTransactions box');
    } catch (e) {
      print(
        '⚠️ Error opening motivationPointsTransactions box, clearing and recreating: $e',
      );
      try {
        await Hive.deleteBoxFromDisk('motivationPointsTransactions');
      } catch (deleteError) {
        print(
          'Note: Could not delete motivationPointsTransactions box (may not exist): $deleteError',
        );
      }
      await Hive.openBox<MotivationPointsTransactionModel>(
        'motivationPointsTransactions',
      );
      print('✓ Recreated motivationPointsTransactions box');
    }

    print('All Hive boxes opened successfully');

    // Initialize default workouts on first install
    try {
      await DefaultWorkoutsService.initializeDefaultWorkouts();
    } catch (e) {
      print('⚠️ Error initializing default workouts: $e');
      // Continue app startup even if default workouts fail
    }

    // Initialize programs (7-minute workouts) on first install
    try {
      await ProgramsService.initializePrograms();
      await ProgramsService.ensureCatalogPrograms();
    } catch (e) {
      print('⚠️ Error initializing programs: $e');
      // Continue app startup even if programs fail
    }

    // Sync audio files from YAML to existing exercises
    try {
      await DefaultWorkoutsService.updateAudioFilesFromYaml();
    } catch (e) {
      print('⚠️ Error syncing audio files: $e');
    }

    // Initialize spritesheets (cut-on-memory, single texture per sheet)
    try {
      await SpriteSheets.init(
        sheets: [
          SheetSource.asset(
            'assets/icon/workout_icons_128px.png',
            tileWidth: 128,
            tileHeight: 128,
            csv: 'assets/icon/workout_icons_128px.csv',
          ),
          SheetSource.asset(
            'assets/icon/motivation_64.png',
            tileWidth: 64,
            tileHeight: 64,
          ),
        ],
        onMissing: MissingSpriteBehavior.transparent,
      );
      print('✓ Loaded spritesheets');
    } catch (e) {
      print('⚠️ Error loading spritesheets: $e');
    }

    try {
      await TestModeBootstrapService.ensureTestData();
    } catch (e) {
      print('⚠️ Error applying test bootstrap data: $e');
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
  final _paletteNotifier = PaletteNotifier();

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    // Listen to palette changes
    _paletteNotifier.addListener(_onPaletteChanged);
  }

  @override
  void dispose() {
    _paletteNotifier.removeListener(_onPaletteChanged);
    super.dispose();
  }

  void _onPaletteChanged() {
    // Reload settings and rebuild when palette changes
    if (mounted) {
      setState(() {
        // This will trigger a rebuild with new palette colors
      });
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final box = Hive.box<UserSettingsModel>('userSettings');
      userSettings = box.get('settings') ?? UserSettingsModel();

      // Migrate old palette names
      if (userSettings.colorPalette == 'original' ||
          userSettings.colorPalette == 'default') {
        userSettings.colorPalette = 'creative';
        await box.put('settings', userSettings);
      } else if (![
        'grayscale',
        'creative',
        'pastel',
      ].contains(userSettings.colorPalette)) {
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

  // Note: Primary color is now determined by the active palette
  // The userSettings.primaryColor is kept for backward compatibility
  // but the actual theme uses AppColorPalette.primary from the active palette

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

    // Use palette colors for theme - all colors come from active palette
    final primaryMaterialColor = AppColorPalette.toMaterialColor(
      AppColorPalette.primary,
    );
    final accentColor = AppColorPalette.accent;
    final backgroundColor = AppColorPalette.background;
    final scaffoldBackgroundColor = AppColorPalette.scaffoldBackground;

    return MaterialApp(
      title: AppEnvironment.isTest
          ? 'Solo Level System (TEST)'
          : 'Solo Level System',
      theme: ThemeData(
        primarySwatch: primaryMaterialColor,
        primaryColor: AppColorPalette.primary,
        colorScheme: ColorScheme.light(
          primary: AppColorPalette.primary,
          secondary: accentColor,
          background: backgroundColor,
          surface: AppColorPalette.backgroundSurface,
          error: AppColorPalette.error,
          onPrimary: AppColorPalette.white,
          onSecondary: AppColorPalette.white,
          onBackground: AppColorPalette.textColor,
          onSurface: AppColorPalette.textColor,
          onError: AppColorPalette.white,
        ),
        scaffoldBackgroundColor: scaffoldBackgroundColor,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: primaryMaterialColor,
        primaryColor: AppColorPalette.primary,
        colorScheme: ColorScheme.dark(
          primary: AppColorPalette.primary,
          secondary: accentColor,
          background: AppColorPalette.backgroundDark,
          surface: AppColorPalette.backgroundDarkSurface,
          error: AppColorPalette.error,
          onPrimary: AppColorPalette.white,
          onSecondary: AppColorPalette.white,
          onBackground: AppColorPalette.white,
          onSurface: AppColorPalette.white,
          onError: AppColorPalette.white,
        ),
        scaffoldBackgroundColor: AppColorPalette.backgroundDark,
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

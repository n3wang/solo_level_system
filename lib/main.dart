import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'models/pomodoro_model.dart';
import 'models/user_settings_model.dart';
import 'models/audio_settings_model.dart';
import 'models/enhanced_audio_model.dart';
import 'models/config_model.dart';

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

    // Open all Hive boxes with detailed logging
    print('Opening Hive boxes...');
    await Hive.openBox<PomodoroModel>('pomodoros');
    print('✓ Opened pomodoros box');
    await Hive.openBox<UserSettingsModel>('userSettings');
    print('✓ Opened userSettings box');
    await Hive.openBox<AudioSettingsModel>('audioSettings');
    print('✓ Opened audioSettings box');
    await Hive.openBox<EnhancedAudioModel>('audioFiles');
    print('✓ Opened audioFiles box');
    await Hive.openBox<ConfigModel>('config');
    print('✓ Opened config box');
    print('All Hive boxes opened successfully');
  } catch (e) {
    print('Hive initialization error: $e');
    print('Stack trace: ${StackTrace.current}');
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
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
    } catch (e) {
      print('Error loading user settings in main: $e');
      userSettings = UserSettingsModel();
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
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'red':
      default:
        return Colors.red;
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
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
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
      home: HomeScreen(onSettingsChanged: _onSettingsChanged),
    );
  }
}

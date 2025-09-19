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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Level System',
      theme: ThemeData(primarySwatch: Colors.red),
      home: HomeScreen(),
    );
  }
}

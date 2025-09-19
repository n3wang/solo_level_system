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
  await Hive.initFlutter();

  // Register all Hive adapters
  Hive.registerAdapter(PomodoroModelAdapter());
  Hive.registerAdapter(UserSettingsModelAdapter());
  Hive.registerAdapter(AudioSettingsModelAdapter());
  Hive.registerAdapter(EnhancedAudioModelAdapter());
  Hive.registerAdapter(ConfigModelAdapter());

  // Open all Hive boxes
  await Hive.openBox<PomodoroModel>('pomodoros');
  await Hive.openBox<UserSettingsModel>('userSettings');
  await Hive.openBox<AudioSettingsModel>('audioSettings');
  await Hive.openBox<EnhancedAudioModel>('audioFiles');
  await Hive.openBox<ConfigModel>('config');

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

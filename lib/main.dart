import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'models/pomodoro_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(PomodoroModelAdapter());
  await Hive.openBox<PomodoroModel>('pomodoros');
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

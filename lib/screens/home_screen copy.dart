import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/history_screen.dart';
import 'package:solo_level_system/utils/audio_utils.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int workMinutes = 25;
  int breakMinutes = 5;
  int remainingSeconds = 1500;
  bool isRunning = false;
  bool onBreak = false;
  Timer? timer;

  void startTimer() {
    setState(() => isRunning = true);
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds == 0) {
        timer.cancel();
        if (!onBreak) {
          setState(() {
            onBreak = true;
            remainingSeconds = breakMinutes * 60;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Break Time!')));
        } else {
          setState(() {
            onBreak = false;
            isRunning = false;
            remainingSeconds = workMinutes * 60;
          });
          saveSession();
        }
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void saveSession() async {
    String? audioPath = await recordAudio(context);
    String? imagePath = await capturePhoto(context);
    final session = PomodoroModel(
      startTime: DateTime.now(),
      audioPath: audioPath,
      imagePath: imagePath,
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    await box.add(session);
    print("Saved session at ${session.startTime}");
  }

  void stopTimer() {
    timer?.cancel();
    setState(() => isRunning = false);
  }

  void resetTimer() {
    stopTimer();
    setState(() => remainingSeconds = workMinutes * 60);
  }

  void recordNow() async {
    String? audioPath = await recordAudio(context);
    final box = Hive.box<PomodoroModel>('pomodoros');
    if (box.isNotEmpty) {
      final last = box.getAt(box.length - 1);
      last?.audioPath = audioPath;
      await last?.save();
    }
  }

  void takePhoto() async {
    String? imagePath = await capturePhoto(context);
    final box = Hive.box<PomodoroModel>('pomodoros');
    if (box.isNotEmpty) {
      final last = box.getAt(box.length - 1);
      last?.imagePath = imagePath;
      await last?.save();
    }
  }

  void createSampleLog() async {
    String? audioPath = await recordAudio(context);
    String? imagePath = await capturePhoto(context);
    final session = PomodoroModel(
      startTime: DateTime.now(),
      audioPath: audioPath,
      imagePath: imagePath,
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    box.add(session);

    print("Saved session at ${session.startTime}");
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pomodoro Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(formatTime(remainingSeconds), style: TextStyle(fontSize: 60)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? null : startTimer,
                  child: Text('Start'),
                ),
                ElevatedButton(
                  onPressed: isRunning ? stopTimer : null,
                  child: Text('Stop'),
                ),
                ElevatedButton(onPressed: resetTimer, child: Text('Reset')),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: createSampleLog,
                  child: Text('Create Log '),
                ),
              ],
            ),
            SizedBox(height: 40),
            Text('Settings:'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<int>(
                  value: workMinutes,
                  items: [15, 25, 1]
                      .map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text('$val min'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    workMinutes = val!;
                    if (!isRunning && !onBreak) remainingSeconds = val * 60;
                  }),
                ),
                DropdownButton<int>(
                  value: breakMinutes,
                  items: [5, 10, 1]
                      .map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text('$val min'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => breakMinutes = val!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

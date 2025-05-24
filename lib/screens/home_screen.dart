import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/history_screen.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:flutter/foundation.dart';

import 'package:solo_level_system/widgets/audio_player.dart';
import 'package:solo_level_system/widgets/audio_recorder.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:solo_level_system/utils/database_utils.dart';

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
  bool showPlayer = false;
  String? audioPath;
  String logStateMessage = "State: ";
  bool allowMusic = true;
  int countCompletedToday = 0;

  final _bgPlayer = ap.AudioPlayer();
  void _playLofi() async {
    if (_bgPlayer.state == ap.PlayerState.playing) {
      await _bgPlayer.stop();
    }

    if (!allowMusic) return;

    List<String> lofiPlaylist = [
      'lofi/lofi-1.mp3',
      'lofi/lofi-2.mp3',
      'lofi/lofi-3.mp3',
      'lofi/lofi-4.mp3',
    ];

    int randomIndex =
        DateTime.now().millisecondsSinceEpoch % lofiPlaylist.length;
    String randomLofi = lofiPlaylist[randomIndex];
    await _bgPlayer.setReleaseMode(ap.ReleaseMode.loop);
    await _bgPlayer.play(ap.AssetSource(randomLofi));
  }

  void _stopLofi() async {
    await _bgPlayer.stop();
  }

  void startTimer() {
    _playLofi();
    setState(() => isRunning = true);
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        _stopLofi();
        timer.cancel();
        if (!onBreak) {
          saveSession();
          setState(() {
            onBreak = true;
            remainingSeconds = breakMinutes * 60;
            logStateMessage = "State: Break";
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Break Time!')));
          isRunning = false;
        } else {
          setState(() {
            onBreak = false;
            isRunning = false;
            remainingSeconds = workMinutes * 60;
            logStateMessage = "State: Work";
          });
        }
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void saveSession() async {
    countCompletedToday++;
    final session = PomodoroModel(
      startTime: DateTime.now(),
      audioPath: audioPath,
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    await box.add(session);
    print("Saved session at ${session.startTime}");
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

  void stopTimer() {
    _stopLofi();
    timer?.cancel();
    if (audioPath != null) {
      final file = File(audioPath!);
      if (file.existsSync()) file.deleteSync();
      audioPath = null;
    }
    setState(() {
      showPlayer = false;
      isRunning = false;
    });
  }

  void resetTimer() {
    stopTimer();
    setState(() => remainingSeconds = workMinutes * 60);
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    getTodayCompletedSessions().then((count) {
      setState(() => countCompletedToday = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lofi Pomodoro'),
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
            Text("Today's sessions: $countCompletedToday"),
            SizedBox(height: 20),

            Text(logStateMessage, style: TextStyle(fontSize: 10)),
            SizedBox(height: 10),
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
                  onPressed: () {
                    setState(
                      () => {
                        // stop usic.
                        _stopLofi(),
                        allowMusic = !allowMusic,
                      },
                    );
                  },
                  child: Text(allowMusic ? 'Mute' : 'Unmute'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (allowMusic) {
                        _playLofi();
                      } else {
                        _stopLofi();
                      }
                      ;
                    });
                  },
                  child: Text(allowMusic ? 'Play M' : 'Stop M'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _stopLofi();
                    setState(() {
                      remainingSeconds = 0;
                    });
                  },
                  child: Text(
                    'Instant Finish ',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            showPlayer
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: AudioPlayer(
                      source: audioPath!,
                      onDelete: () => setState(() => showPlayer = false),
                    ),
                  )
                : Recorder(
                    onStop: (path) {
                      if (kDebugMode) print('Recorded file path: $path');
                      setState(() {
                        audioPath = path;
                        showPlayer = true;
                      });
                    },
                  ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text("Take Photo"),
              onPressed: takePhoto,
            ),
            SizedBox(height: 40),
            Text('Settings:'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<int>(
                  value: workMinutes,
                  items: [1, 15, 25]
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
                  items: [1, 5, 10]
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

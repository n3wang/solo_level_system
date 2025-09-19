import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/history_screen.dart';
import 'package:solo_level_system/screens/config_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
import 'package:solo_level_system/screens/audio_management_screen.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/widgets/enhanced_audio_player.dart';
import 'package:solo_level_system/widgets/enhanced_audio_recorder.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
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
  bool canSubmitLog = false;
  String? imagePath;
  String? currentlyPlayingTrack;
  ConfigModel? config;
  int lastTrackIndex = 0;

  final _bgPlayer = ap.AudioPlayer();

  void _playLofi() async {
    if (_bgPlayer.state == ap.PlayerState.playing) await _bgPlayer.stop();
    if (!allowMusic) return;

    List<String> lofiPlaylist = [
      'lofi/lofi-1.mp3',
      'lofi/lofi-2.mp3',
      'lofi/lofi-3.mp3',
      'lofi/lofi-4.mp3',
      'lofi/13-high-rise-114783.mp3',
      'lofi/15-lofi-study-calm-peaceful-chill-hop-musicno-copyright-346767.mp3',
      'lofi/16-study-110111.mp3',
      'lofi/17-lofi-study-calm-peaceful-chill-hop-112191.mp3',
      'lofi/18-relaxing-ambient-music-nostalgic-memories-310690.mp3',
      'lofi/19-dark-academia-melancholy-262441.mp3',
      'lofi/20-cops-first-day-on-the-job-anasta-music-293360.mp3',
      'lofi/21-mezhdunami-voyager-141276.mp3',
      'lofi/22-the-peoplex27s-land-336886.mp3',
      'lofi/23-ghibli-style-1-229069.mp3',
      'lofi/24-days-for-you-336889.mp3',
      'lofi/25-ghibli-style-2-229070.mp3',
      'lofi/26-thought-336888.mp3',
      'lofi/27-the-best-detective-190125.mp3',
      'lofi/29-singularity-abstract-electronica-281092.mp3',
      'lofi/30-awake-the-science-technology-electronica-281089.mp3',
      'lofi/31-lo-fi-for-the-best-vlogs-266458.mp3',
      'lofi/32-lofi-soul-268728.mp3',
      'lofi/33-a-new-scientific-research-304924.mp3',
      'lofi/34-london-fashion-week-304935.mp3',
      'lofi/35-resurrection-327870.mp3',
      'lofi/36-the-world-of-science-285320.mp3',
      'lofi/37-secret-lab-194422.mp3',
      'lofi/38-doctor-science-calm-electronica-283173.mp3',
      'lofi/39-shattered-339166.mp3',
      'lofi/40-cqb-tense-80s-synthwave-instrumental-345187.mp3',
      'lofi/41-a-hero-of-the-80s-126684.mp3',
      'lofi/42-balenciaga-trap-music-111733.mp3',
      'lofi/43-neon-adventure-deep-fashion-house-273895.mp3',
    ];

    int trackIndex;
    if (config?.randomizeAudio == true) {
      trackIndex = Random().nextInt(lofiPlaylist.length);
    } else {
      trackIndex = (lastTrackIndex + 1) % lofiPlaylist.length;
    }
    lastTrackIndex = trackIndex;

    String track = lofiPlaylist[trackIndex];
    String trackName = track.split('/').last.replaceAll('.mp3', '').replaceAll('-', ' ');
    setState(() {
      currentlyPlayingTrack = trackName;
    });

    ap.ReleaseMode releaseMode = (config?.playAudioOnRepeat == true)
        ? ap.ReleaseMode.loop
        : ap.ReleaseMode.release;
    await _bgPlayer.setReleaseMode(releaseMode);
    await _bgPlayer.play(ap.AssetSource(track));
  }

  void _stopLofi() async {
    await _bgPlayer.stop();
    setState(() {
      currentlyPlayingTrack = null;
    });
  }

  void startTimer() {
    _playLofi();
    setState(() => isRunning = true);
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        _stopLofi();
        timer.cancel();
        if (!onBreak) {
          setState(() {
            isRunning = false;
            canSubmitLog = true;
            logStateMessage = "State: Finished – Submit Log";
          });
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

  void submitLog() {
    saveSession();
    setState(() {
      audioPath = null;
      showPlayer = false;
      canSubmitLog = false;
      onBreak = true;
      remainingSeconds = breakMinutes * 60;
      logStateMessage = "State: Break";
    });

    startTimer();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Break Time!')));
  }

  void saveSession({cleanVariables = true}) async {
    countCompletedToday++;
    final session = PomodoroModel(
      startTime: DateTime.now(),
      audioPath: audioPath,
      imagePath: imagePath,
      dayPomodoroNumber: countCompletedToday + 1,
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    await box.add(session);
    print("Saved session at ${session.startTime}");
    if (cleanVariables) {
      audioPath = null;
      imagePath = null;
      showPlayer = false;
    }
  }

  void takePhoto() async {
    String? path = await capturePhoto(context);

    if (path != null) {
      setState(() {
        imagePath = path;
      });
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

  void instantFinish() {
    setState(() {
      remainingSeconds = 0;
    });
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
    getTodayCompletedSessions().then((count) {
      setState(() => countCompletedToday = count);
    });
  }

  Future<void> _loadConfig() async {
    final box = await Hive.openBox<ConfigModel>('config');
    config = box.get('settings') ?? ConfigModel.getDefault();
    setState(() {});
  }

  Future<EnhancedAudioModel?> _getEnhancedAudioByPath(String path) async {
    final box = await Hive.openBox<EnhancedAudioModel>('audioFiles');
    final existingAudio = box.values.where((audio) => audio.filePath == path).firstOrNull;

    if (existingAudio != null) {
      return existingAudio;
    }

    // Create a new audio model with default values
    final audioModel = EnhancedAudioModel(
      filePath: path,
      fileName: path.split('/').last,
      createdAt: DateTime.now(),
      durationMs: 0, // Default, will be updated when played
      fileSizeBytes: 0, // Default, will be updated when file is analyzed
      format: 'm4a', // Default format
      bitRate: 64000, // Default bitrate
      sampleRate: 44100, // Default sample rate
      channels: 1, // Mono recording
      category: 'voice_note',
    );

    // Save to box
    await box.add(audioModel);
    return audioModel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lofi Pomodoro'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen()),
                  ).then((_) => _loadConfig());
                  break;
                case 'config':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ConfigScreen()),
                  ).then((_) => _loadConfig());
                  break;
                case 'audio':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AudioManagementScreen()),
                  );
                  break;
                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoryScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'config',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Configuration'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'audio',
                child: ListTile(
                  leading: Icon(Icons.audiotrack),
                  title: Text('Audio Management'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('History'),
                  dense: true,
                ),
              ),
            ],
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
            if (currentlyPlayingTrack != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Playing: $currentlyPlayingTrack',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
            ],
            Text(logStateMessage, style: TextStyle(fontSize: 10)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isRunning && !canSubmitLog)
                  ElevatedButton(onPressed: startTimer, child: Text('Start')),
                if (isRunning)
                  ElevatedButton(onPressed: stopTimer, child: Text('Stop')),
                if (!isRunning && canSubmitLog)
                  TextButton(
                    onPressed: submitLog,
                    child: Text(
                      '[Submit Log]',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ElevatedButton(onPressed: resetTimer, child: Text('Reset')),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (allowMusic) {
                        _stopLofi();
                      }
                      allowMusic = !allowMusic;
                    });
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
                    });
                  },
                  child: Text(allowMusic ? 'Play M' : 'Stop M'),
                ),
                if (!canSubmitLog)
                  ElevatedButton(
                    onPressed: instantFinish,
                    child: Text(
                      'Instant Finish',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            if (config?.showAudioRecordButton == true) ...[
              showPlayer && audioPath != null
                  ? FutureBuilder<EnhancedAudioModel?>(
                      future: _getEnhancedAudioByPath(audioPath!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: EnhancedAudioPlayer(
                              audioModel: snapshot.data!,
                              onDelete: () {
                                setState(() {
                                  audioPath = null;
                                  showPlayer = false;
                                });
                              },
                            ),
                          );
                        }
                        return CircularProgressIndicator();
                      },
                    )
                  : EnhancedAudioRecorder(
                      onRecordingComplete: (audioModel) {
                        setState(() {
                          audioPath = audioModel.filePath;
                          showPlayer = true;
                          canSubmitLog = true;
                        });
                      },
                      category: 'voice_note',
                    ),
              SizedBox(height: 20),
            ],
            if (config?.showPhotoButton == true)
              ElevatedButton.icon(
                icon: Icon(Icons.camera_alt),
                label: imagePath != null
                    ? Text('Photo Taken')
                    : Text('Take Photo'),
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

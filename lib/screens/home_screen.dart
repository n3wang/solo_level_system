import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/history_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
import 'package:solo_level_system/screens/audio_management_screen.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/widgets/enhanced_audio_player.dart';
import 'package:solo_level_system/widgets/enhanced_audio_recorder.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:solo_level_system/utils/database_utils.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/lofi_service.dart';
import 'package:solo_level_system/models/lofi_track.dart';
import 'package:solo_level_system/utils/sound_effects_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const HomeScreen({Key? key, this.onSettingsChanged}) : super(key: key);

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
  EnhancedAudioModel? recordedAudio;
  String logStateMessage = "State: ";
  bool allowMusic = true;
  int countCompletedToday = 0;
  bool canSubmitLog = false;
  String? imagePath;
  String? currentlyPlayingTrack;
  ConfigModel? config;
  UserSettingsModel? userSettings;
  int lastTrackIndex = 0;

  final _bgPlayer = ap.AudioPlayer();
  final _backgroundMusicService = BackgroundMusicService();
  final _soundEffectsService = SoundEffectsService();

  // Helper method to check if recording/photo features should be available
  bool get _shouldShowRecordingFeatures {
    // Only show during break or when stopped (not during active work session)
    return !isRunning || onBreak || canSubmitLog;
  }

  void _playLofi() async {
    if (_backgroundMusicService.isPlaying) {
      await _backgroundMusicService.stop();
    }
    if (!allowMusic) return;

    try {
      // Set looping based on config
      _backgroundMusicService.setLooping(config?.playAudioOnRepeat ?? false);

      await _backgroundMusicService.playRandomTrack();

      final currentTrack = _backgroundMusicService.currentTrack;
      if (currentTrack != null) {
        logStateMessage = 'Music: ${currentTrack.title}';
        setState(() {
          currentlyPlayingTrack = currentTrack.title;
        });
      }
    } catch (e) {
      print('Failed to play lofi music: $e');
      logStateMessage = 'Music: Failed to load';
      setState(() {
        currentlyPlayingTrack = 'Error loading music';
      });
    }
  }

  void _stopLofi() async {
    await _backgroundMusicService.stop();
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
          // Work session finished
          _soundEffectsService.playWorkTimeCompleted();
          setState(() {
            isRunning = false;
            canSubmitLog = true;
            logStateMessage = "State: Finished – Submit Log";
          });

          // Auto-start break if enabled
          if (userSettings?.autoStartBreaks == true) {
            Future.delayed(Duration(seconds: 2), () {
              if (canSubmitLog) {
                // Only if user hasn't manually submitted
                submitLog();
              }
            });
          }
        } else {
          // Break finished
          _soundEffectsService.playBreakTimeEnds();
          setState(() {
            onBreak = false;
            isRunning = false;
            remainingSeconds = workMinutes * 60;
            logStateMessage = "State: Work";
          });

          // Auto-start work if enabled
          if (userSettings?.autoStartWork == true) {
            Future.delayed(Duration(seconds: 2), () {
              if (!isRunning) {
                // Only if user hasn't manually started
                startTimer();
              }
            });
          }
        }
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void submitLog() {
    saveSession();
    _soundEffectsService.playBreakTimeStarts();
    setState(() {
      audioPath = null;
      recordedAudio = null;
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
      recordedAudio = null;
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
      recordedAudio = null;
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
    // Simplified initialization to prevent hanging
    _safeInitialize();
  }

  void _safeInitialize() async {
    try {
      await _loadConfig();
      await _loadUserSettings();
      await _backgroundMusicService.initialize();
      final count = await getTodayCompletedSessions();
      if (mounted) {
        setState(() => countCompletedToday = count);
      }
    } catch (e) {
      print('Initialization error: $e');
      // Continue with defaults even if initialization fails
      if (mounted) {
        setState(() {
          countCompletedToday = 0;
        });
      }
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final box = Hive.box<UserSettingsModel>('userSettings');
      userSettings = box.get('settings') ?? UserSettingsModel();
      setState(() {
        workMinutes = userSettings!.defaultWorkMinutes;
        breakMinutes = userSettings!.defaultBreakMinutes;
        if (!isRunning && !onBreak) {
          remainingSeconds = workMinutes * 60;
        }
      });
    } catch (e) {
      print('Error loading user settings: $e');
      setState(() {
        workMinutes = 25;
        breakMinutes = 5;
        remainingSeconds = workMinutes * 60;
      });
    }
  }

  Future<void> _loadConfig() async {
    try {
      final box = Hive.box<ConfigModel>('config');
      config = box.get('settings') ?? ConfigModel.getDefault();
      setState(() {});
    } catch (e) {
      print('Error loading config: $e');
      config = ConfigModel.getDefault();
      setState(() {});
    }
  }

  Future<EnhancedAudioModel?> _getEnhancedAudioByPath(String path) async {
    try {
      final box = Hive.box<EnhancedAudioModel>('audioFiles');
      final existingAudio = box.values
          .where((audio) => audio.filePath == path)
          .firstOrNull;

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
    } catch (e) {
      print('Error loading enhanced audio: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen()),
                  ).then((_) {
                    _loadConfig();
                    _loadUserSettings();
                    widget.onSettingsChanged?.call();
                  });
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Main Timer Display
              _buildTimerSection(),

              SizedBox(height: 20),

              // Control Buttons
              _buildControlButtons(),

              SizedBox(height: 20),

              // Audio Controls
              _buildAudioControls(),

              SizedBox(height: 20),

              // Recording and Photo Section (conditional)
              _buildConditionalRecordingSection(),

              SizedBox(height: 40), // Extra padding at bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSection() {
    return Column(
      children: [
        Text(formatTime(remainingSeconds), style: TextStyle(fontSize: 60)),
        Text("Today's sessions: $countCompletedToday"),
        SizedBox(height: 20),
        _buildCurrentTrackWidget(),
        Text(logStateMessage, style: TextStyle(fontSize: 10)),
        SizedBox(height: 10),
        _buildFocusModeWidget(),
      ],
    );
  }

  Widget _buildCurrentTrackWidget() {
    return Container(
      key: ValueKey('current_track_widget'),
      child: currentlyPlayingTrack != null
          ? Column(
              children: [
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
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
              ],
            )
          : SizedBox.shrink(),
    );
  }

  Widget _buildFocusModeWidget() {
    return Container(
      key: ValueKey('focus_mode_widget'),
      child: (!_shouldShowRecordingFeatures && isRunning && !onBreak)
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.work, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Focus mode: Recording features disabled',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ],
              ),
            )
          : SizedBox.shrink(),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isRunning && !canSubmitLog)
          ElevatedButton(onPressed: startTimer, child: Text('Start')),
        if (isRunning)
          ElevatedButton(onPressed: stopTimer, child: Text('Stop')),
        if (!isRunning && canSubmitLog)
          TextButton(
            onPressed: submitLog,
            child: Text('[Submit Log]', style: TextStyle(color: Colors.green)),
          ),
        ElevatedButton(onPressed: resetTimer, child: Text('Reset')),
      ],
    );
  }

  Widget _buildAudioControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
            child: Text('Instant Finish', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildConditionalRecordingSection() {
    return Container(
      key: ValueKey('conditional_recording_section'),
      child: _shouldShowRecordingFeatures
          ? Column(children: [_buildRecordingSection(), SizedBox(height: 20)])
          : SizedBox(height: 20),
    );
  }

  Widget _buildRecordingSection() {
    return Column(
      key: ValueKey('recording_section'),
      children: [
        Text(
          'Session Recording',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        _buildAudioSection(),
        SizedBox(height: 16),
        _buildPhotoSection(),
      ],
    );
  }

  Widget _buildAudioSection() {
    return Container(
      key: ValueKey('audio_section_container'),
      child: config?.showAudioRecordButton == true
          ? (showPlayer && recordedAudio != null)
                ? Column(
                    children: [
                      EnhancedAudioPlayer(
                        audioModel: recordedAudio!,
                        onDelete: () {
                          setState(() {
                            audioPath = null;
                            recordedAudio = null;
                            showPlayer = false;
                          });
                        },
                      ),
                    ],
                  )
                : EnhancedAudioRecorder(
                    onRecordingComplete: (EnhancedAudioModel audioModel) {
                      _soundEffectsService.playAudioRecordSubmitted();
                      setState(() {
                        audioPath = audioModel.filePath;
                        recordedAudio = audioModel;
                        showPlayer = true;
                        canSubmitLog = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Recording completed successfully!'),
                        ),
                      );
                    },
                    category: 'voice_note',
                  )
          : SizedBox.shrink(),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      key: ValueKey('photo_section_container'),
      child: config?.showPhotoButton == true
          ? ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: imagePath != null
                  ? Text('Photo Taken')
                  : Text('Take Photo'),
              onPressed: takePhoto,
            )
          : SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _bgPlayer.dispose();
    _backgroundMusicService.dispose();
    _soundEffectsService.dispose();
    super.dispose();
  }
}

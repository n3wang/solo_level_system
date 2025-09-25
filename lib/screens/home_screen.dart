import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/history_screen.dart';
import 'package:solo_level_system/screens/settings_screen.dart';
import 'package:solo_level_system/screens/audio_management_screen.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:solo_level_system/utils/database_utils.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/sound_effects_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

// New imports for refactored widgets and constants
import 'package:solo_level_system/utils/pomodoro_sizing.dart';
import 'package:solo_level_system/widgets/pomodoro/compact_music_widget.dart';
import 'package:solo_level_system/widgets/pomodoro/session_squares_widget.dart';

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

  void _playLofi() async {
    if (_backgroundMusicService.isPlaying) {
      await _backgroundMusicService.stop();
    }
    if (!allowMusic) return;

    try {
      // Set looping based on config
      _backgroundMusicService.setLooping(config?.playAudioOnRepeat ?? false);

      await _backgroundMusicService.playRandomTrack();

      // Update the current track display
      setState(() {
        final track = _backgroundMusicService.currentTrack;
        currentlyPlayingTrack = track?.title ?? 'Unknown Track';
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Main Timer Display
              _buildTimerSection(),

              // Recording and Photo Section (conditional)
              // _buildConditionalRecordingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSection() {
    return Column(
      children: [
        // Timer with recording buttons when session complete
        canSubmitLog ? _buildTimerWithRecordingButtons() : _buildGestureTimer(),
      ],
    );
  }

  Widget _buildGestureTimer() {
    return GestureDetector(
      onTap: () {
        // Click timer to start/stop/submit log
        if (isRunning) {
          stopTimer();
        } else if (canSubmitLog) {
          submitLog();
        } else {
          startTimer();
        }
      },
      onVerticalDragEnd: (details) {
        // Swipe up for instant finish, swipe down for reset
        if (details.velocity.pixelsPerSecond.dy < -300) {
          // Swipe up - instant finish
          if (isRunning) {
            instantFinish();
          }
        } else if (details.velocity.pixelsPerSecond.dy > 300) {
          // Swipe down - reset timer
          if (!isRunning) {
            resetTimer();
          }
        }
      },
      child: Container(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: MediaQuery.of(context).size.width > 600
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Album image with timer overlay
                  Container(
                    width: PomodoroSizing.getAlbumContainerSize(context),
                    height: PomodoroSizing.getAlbumContainerSize(context),
                    child: Stack(
                      children: [
                        // Album background image
                        Container(
                          width: PomodoroSizing.getAlbumContainerSize(context),
                          height: PomodoroSizing.getAlbumContainerSize(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRunning ? Colors.red : Colors.green,
                              width: 2,
                            ),
                            image:
                                _backgroundMusicService
                                        .currentTrack
                                        ?.albumImagePath !=
                                    null
                                ? DecorationImage(
                                    image: AssetImage(
                                      _backgroundMusicService
                                          .currentTrack!
                                          .albumImagePath!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color:
                                _backgroundMusicService
                                        .currentTrack
                                        ?.albumImagePath ==
                                    null
                                ? (isRunning
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1))
                                : null,
                          ),
                        ),
                        // Timer overlay with semi-transparent background
                        Container(
                          width: PomodoroSizing.getAlbumContainerSize(context),
                          height: PomodoroSizing.getAlbumContainerSize(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatTime(remainingSeconds),
                                style: TextStyle(
                                  fontSize: PomodoroSizing.getTimerFontSize(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10.0,
                                      color: Colors.black,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                isRunning
                                    ? (onBreak
                                          ? 'Break Time - Tap to Stop'
                                          : 'Focus Time - Tap to Stop')
                                    : canSubmitLog
                                    ? 'Session Complete - Tap to Submit!'
                                    : 'Tap to Start • ↑ Finish • ↓ Reset',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5.0,
                                      color: Colors.black,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              SessionSquaresWidget(
                                completedSessions: countCompletedToday,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 20),

                  // Music widget next to album (hidden when paused)
                  if (isRunning || canSubmitLog)
                    Container(
                      width: PomodoroSizing.getMusicWidgetWidth(context),
                      child: CompactMusicWidget(
                        allowMusic: allowMusic,
                        currentlyPlayingTrack: currentlyPlayingTrack,
                        onToggleMusic: () {
                          setState(() {
                            if (allowMusic) {
                              _stopLofi();
                              allowMusic = false;
                            } else {
                              allowMusic = true;
                              if (isRunning) {
                                _playLofi();
                              }
                            }
                          });
                        },
                        onChangeTrack: () {
                          if (allowMusic) {
                            _playLofi(); // This plays a random track
                          }
                        },
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top padding to match bottom spacing
                  SizedBox(height: 20),
                  // Album image with timer overlay
                  Container(
                    width: PomodoroSizing.getAlbumContainerSize(context),
                    height: PomodoroSizing.getAlbumContainerSize(context),
                    child: Stack(
                      children: [
                        // Album background image
                        Container(
                          width: PomodoroSizing.getAlbumContainerSize(context),
                          height: PomodoroSizing.getAlbumContainerSize(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRunning ? Colors.red : Colors.green,
                              width: 2,
                            ),
                            image:
                                _backgroundMusicService
                                        .currentTrack
                                        ?.albumImagePath !=
                                    null
                                ? DecorationImage(
                                    image: AssetImage(
                                      _backgroundMusicService
                                          .currentTrack!
                                          .albumImagePath!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color:
                                _backgroundMusicService
                                        .currentTrack
                                        ?.albumImagePath ==
                                    null
                                ? (isRunning
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1))
                                : null,
                          ),
                        ),
                        // Timer overlay with semi-transparent background
                        Container(
                          width: PomodoroSizing.getAlbumContainerSize(context),
                          height: PomodoroSizing.getAlbumContainerSize(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatTime(remainingSeconds),
                                style: TextStyle(
                                  fontSize: PomodoroSizing.getTimerFontSize(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10.0,
                                      color: Colors.black,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                isRunning
                                    ? (onBreak
                                          ? 'Break Time - Tap to Stop'
                                          : 'Focus Time - Tap to Stop')
                                    : canSubmitLog
                                    ? 'Session Complete - Tap to Submit!'
                                    : 'Tap to Start • ↑ Finish • ↓ Reset',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5.0,
                                      color: Colors.black,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              SessionSquaresWidget(
                                completedSessions: countCompletedToday,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Music widget below album for small screens (hidden when paused)
                  if (isRunning || canSubmitLog) ...[
                    SizedBox(height: 20),
                    Container(
                      width: PomodoroSizing.getAlbumContainerSize(
                        context,
                      ).clamp(150.0, 400.0),
                      child: CompactMusicWidget(
                        allowMusic: allowMusic,
                        currentlyPlayingTrack: currentlyPlayingTrack,
                        onToggleMusic: () {
                          setState(() {
                            if (allowMusic) {
                              _stopLofi();
                              allowMusic = false;
                            } else {
                              allowMusic = true;
                              if (isRunning) {
                                _playLofi();
                              }
                            }
                          });
                        },
                        onChangeTrack: () {
                          if (allowMusic) {
                            _playLofi(); // This plays a random track
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTimerWithRecordingButtons() {
    return MediaQuery.of(context).size.width > 600
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Album image with timer overlay (center)
              Container(
                width: PomodoroSizing.getAlbumContainerSize(context),
                height: PomodoroSizing.getAlbumContainerSize(context),
                child: GestureDetector(
                  onTap: () {
                    if (canSubmitLog) {
                      submitLog();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (details.velocity.pixelsPerSecond.dy < -300) {
                      if (isRunning) {
                        instantFinish();
                      }
                    } else if (details.velocity.pixelsPerSecond.dy > 300) {
                      if (!isRunning) {
                        resetTimer();
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      // Timer overlay with semi-transparent background
                      Container(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatTime(remainingSeconds),
                              style: TextStyle(
                                fontSize: PomodoroSizing.getTimerFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Session Complete - Tap to Submit!',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(
                                    blurRadius: 5.0,
                                    color: Colors.black,
                                    offset: Offset(1.0, 1.0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            SessionSquaresWidget(
                              completedSessions: countCompletedToday,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // vertical stack for horizontal layout
              Column(
                children: [
                  // Recording button (right side)
                  if (config?.showAudioRecordButton == true)
                    Container(
                      margin: EdgeInsets.only(left: 20, top: 10, bottom: 10),
                      child: _buildSimplifiedRecordingButton(),
                    ),

                  if (config?.showPhotoButton == true)
                    Container(
                      margin: EdgeInsets.only(left: 20, bottom: 10),
                      child: _buildSquareEvidenceButton(),
                    ),
                  if (isRunning || canSubmitLog)
                    Container(
                      width: PomodoroSizing.getMusicWidgetWidth(context),
                      margin: EdgeInsets.only(left: 20, top: 10),
                      child: CompactMusicWidget(
                        allowMusic: allowMusic,
                        currentlyPlayingTrack: currentlyPlayingTrack,
                        onToggleMusic: () {
                          setState(() {
                            if (allowMusic) {
                              _stopLofi();
                              allowMusic = false;
                            } else {
                              allowMusic = true;
                              if (isRunning) {
                                _playLofi();
                              }
                            }
                          });
                        },
                        onChangeTrack: () {
                          if (allowMusic) {
                            _playLofi(); // This plays a random track
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top padding to match bottom spacing
              SizedBox(height: 20),
              // Album image with timer overlay for vertical layout
              Container(
                width: PomodoroSizing.getAlbumContainerSize(context),
                height: PomodoroSizing.getAlbumContainerSize(context),
                child: GestureDetector(
                  onTap: () {
                    if (canSubmitLog) {
                      submitLog();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (details.velocity.pixelsPerSecond.dy < -300) {
                      if (isRunning) {
                        instantFinish();
                      }
                    } else if (details.velocity.pixelsPerSecond.dy > 300) {
                      if (!isRunning) {
                        resetTimer();
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      // Timer overlay with semi-transparent background
                      Container(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatTime(remainingSeconds),
                              style: TextStyle(
                                fontSize: PomodoroSizing.getTimerFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Session Complete - Tap to Submit!',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(
                                    blurRadius: 5.0,
                                    color: Colors.black,
                                    offset: Offset(1.0, 1.1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            SessionSquaresWidget(
                              completedSessions: countCompletedToday,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recording and camera buttons below timer for vertical layout
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Recording button
                  if (config?.showAudioRecordButton == true) ...[
                    _buildSimplifiedRecordingButton(),
                    if (config?.showPhotoButton == true) SizedBox(width: 20),
                  ],

                  // Camera button
                  if (config?.showPhotoButton == true)
                    _buildSquareEvidenceButton(),
                ],
              ),

              // Music widget below recording buttons for vertical layout
              if (isRunning || canSubmitLog) ...[
                SizedBox(height: 20),
                Container(
                  width: PomodoroSizing.getAlbumContainerSize(
                    context,
                  ).clamp(150.0, 400.0),
                  child: CompactMusicWidget(
                    allowMusic: allowMusic,
                    currentlyPlayingTrack: currentlyPlayingTrack,
                    onToggleMusic: () {
                      setState(() {
                        if (allowMusic) {
                          _stopLofi();
                          allowMusic = false;
                        } else {
                          allowMusic = true;
                          if (isRunning) {
                            _playLofi();
                          }
                        }
                      });
                    },
                    onChangeTrack: () {
                      if (allowMusic) {
                        _playLofi(); // This plays a random track
                      }
                    },
                  ),
                ),
              ],
            ],
          );
  }

  Widget _buildSquareEvidenceButton() {
    return GestureDetector(
      onTap: takePhoto,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: (imagePath != null)
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (imagePath != null) ? Colors.green : Colors.orange,
            width: 2,
          ),
        ),
        child: Icon(
          (imagePath != null) ? Icons.camera_alt : Icons.camera_alt_outlined,
          size: 24,
          color: (imagePath != null) ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildSimplifiedRecordingButton() {
    return _SimplifiedRecordingWidget(
      onRecordingComplete: (audioModel) {
        _soundEffectsService.playAudioRecordSubmitted();
        setState(() {
          audioPath = audioModel.filePath;
          recordedAudio = audioModel;
          showPlayer = true;
          canSubmitLog = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording completed successfully!')),
        );
      },
      onReset: () {
        setState(() {
          audioPath = null;
          recordedAudio = null;
          showPlayer = false;
        });
      },
      hasRecording: audioPath != null,
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

class _SimplifiedRecordingWidget extends StatefulWidget {
  final Function(EnhancedAudioModel) onRecordingComplete;
  final VoidCallback onReset;
  final bool hasRecording;

  const _SimplifiedRecordingWidget({
    required this.onRecordingComplete,
    required this.onReset,
    required this.hasRecording,
  });

  @override
  State<_SimplifiedRecordingWidget> createState() =>
      _SimplifiedRecordingWidgetState();
}

class _SimplifiedRecordingWidgetState extends State<_SimplifiedRecordingWidget>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  Timer? _levelTimer;

  List<double> _audioLevels = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _audioLevels.clear();
      });

      _pulseController.repeat(reverse: true);
      _startTimer();
      _startLevelMonitoring();
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      _timer?.cancel();
      _levelTimer?.cancel();
      _pulseController.stop();

      if (path != null) {
        final audioModel = EnhancedAudioModel(
          filePath: path,
          fileName: path.split('/').last,
          createdAt: DateTime.now(),
          durationMs: _recordingDuration.inMilliseconds,
          fileSizeBytes: 0, // Will be calculated later
          format: 'wav',
          bitRate: 128000,
          sampleRate: 44100,
          channels: 1,
          title: 'Session Recording',
          description: 'Pomodoro session recording',
          tags: ['session'],
          category: 'session',
          waveformData: _audioLevels,
        );
        widget.onRecordingComplete(audioModel);
      }

      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(
          seconds: _recordingDuration.inSeconds + 1,
        );
      });
    });
  }

  void _startLevelMonitoring() {
    _levelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      try {
        final amplitude = await _recorder.getAmplitude();
        final level = amplitude.current.clamp(0.0, 1.0);

        setState(() {
          _audioLevels.add(level);
          if (_audioLevels.length > 50) {
            _audioLevels.removeAt(0);
          }
        });
      } catch (e) {
        // Handle amplitude error silently
      }
    });
  }

  Widget _buildAudioLevelsVisualization() {
    if (!_isRecording) return SizedBox.shrink();

    return Positioned.fill(
      child: CustomPaint(painter: _AudioLevelsPainter(_audioLevels)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRecording ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () {
              if (widget.hasRecording && !_isRecording) {
                widget.onReset();
              } else if (_isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withOpacity(0.1)
                    : widget.hasRecording
                    ? Colors.green.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording
                      ? Colors.red
                      : widget.hasRecording
                      ? Colors.green
                      : Colors.blue,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  _buildAudioLevelsVisualization(),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRecording
                              ? Icons.stop
                              : widget.hasRecording
                              ? Icons.refresh
                              : Icons.mic,
                          size: 24,
                          color: _isRecording
                              ? Colors.red
                              : widget.hasRecording
                              ? Colors.green
                              : Colors.blue,
                        ),
                        if (_isRecording) ...[
                          SizedBox(height: 4),
                          Text(
                            '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

class _AudioLevelsPainter extends CustomPainter {
  final List<double> levels;

  _AudioLevelsPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    final barWidth = size.width / levels.length;

    for (int i = 0; i < levels.length; i++) {
      final barHeight = levels[i] * (size.height * 0.6);
      final x = i * barWidth + barWidth / 2;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

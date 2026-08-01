// lib/screens/program_running_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/models/exercise_model.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';
import 'package:solo_level_system/utils/exercise_audio_service.dart';

class ProgramRunningScreen extends StatefulWidget {
  final TimedWorkoutModel program;

  const ProgramRunningScreen({super.key, required this.program});

  @override
  _ProgramRunningScreenState createState() => _ProgramRunningScreenState();
}

class _ProgramRunningScreenState extends State<ProgramRunningScreen> {
  Timer? _timer;
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  bool _isPaused = false;
  bool _hasStarted = false;
  int _totalElapsedSeconds = 0;
  bool _hasPlayed5SecondWarning = false;
  Set<int> _playedCountdownNumbers = {}; // Track which countdown numbers have been played
  final _audioService = ExerciseAudioService();

  List<TimedWorkoutItem> get _workoutItems => widget.program.workoutOrder;
  TimedWorkoutItem? get _currentItem =>
      _currentIndex < _workoutItems.length ? _workoutItems[_currentIndex] : null;

  @override
  void initState() {
    super.initState();
    _initializeWorkout();
  }

  void _initializeWorkout() {
    if (_workoutItems.isNotEmpty) {
      _remainingSeconds = _workoutItems[0].time;
      _hasPlayed5SecondWarning = false;
      _playedCountdownNumbers.clear();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  /// Periodic tick while a session is active. Pauses only gate countdown decrements,
  /// but the timer must stay scheduled whenever [_hasStarted] — otherwise skip/next/restart
  /// while paused cancel [_timer] and resume would play audio without ticking.
  void _ensureTickTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
          _totalElapsedSeconds++;

          // Play "5 seconds left" warning when exactly 5 seconds remain
          if (_remainingSeconds == 5 && !_hasPlayed5SecondWarning) {
            _hasPlayed5SecondWarning = true;
            _audioService.play5SecondsLeft();
            // Also play countdown 5 after a short delay
            Future.delayed(const Duration(milliseconds: 800), () {
              if (_remainingSeconds == 5 && !_playedCountdownNumbers.contains(5)) {
                _playedCountdownNumbers.add(5);
                _audioService.playCountdown(5);
              }
            });
          }

          // Play countdown audio for last 4 seconds (4, 3, 2, 1)
          if (_remainingSeconds >= 1 && _remainingSeconds <= 4) {
            if (!_playedCountdownNumbers.contains(_remainingSeconds)) {
              _playedCountdownNumbers.add(_remainingSeconds);
              _audioService.playCountdown(_remainingSeconds);
            }
          }

          // Move to next exercise when time is up
          if (_remainingSeconds <= 0) {
            _moveToNextExercise();
          }
        });
      }
    });
  }

  void _startTimer() {
    if (_isPaused) {
      _resumeTimer();
      return;
    }

    _hasStarted = true;
    // Play audio for the first exercise
    _loadCurrentExerciseAndPlayAudio();

    _ensureTickTimer();
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
      _hasPlayed5SecondWarning = false;
      // Reset countdown tracking when resuming
      _playedCountdownNumbers.clear();
    });
    // Play exercise audio when unpausing
    _loadCurrentExerciseAndPlayAudio();
    if (_hasStarted) {
      _ensureTickTimer();
    }
  }

  void _moveToNextExercise() {
    _moveToExerciseIndex(_currentIndex + 1);
  }

  void _moveToExerciseIndex(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= _workoutItems.length) {
      if (targetIndex >= _workoutItems.length) {
        // Workout complete
        _completeWorkout();
      }
      return;
    }

    _timer?.cancel();
    _hasPlayed5SecondWarning = false;
    _playedCountdownNumbers.clear();

    setState(() {
      _currentIndex = targetIndex;
      _remainingSeconds = _workoutItems[_currentIndex].time;
    });

    // Get current exercise to check if it's a break
    _loadCurrentExerciseAndPlayAudio();

    // Recreate tick timer whenever the session had started (including while paused).
    if (_hasStarted) {
      _ensureTickTimer();
    }
  }

  Future<void> _loadCurrentExerciseAndPlayAudio() async {
    print('[ProgramRunning] _loadCurrentExerciseAndPlayAudio called');
    
    if (_currentItem == null) {
      print('[ProgramRunning] ✗ _currentItem is null, cannot load audio');
      return;
    }

    final exercisesBox = Hive.box<ExerciseModel>('exercises');
    final exercise = exercisesBox.get(_currentItem!.workoutId);

    if (exercise == null) {
      print('[ProgramRunning] ✗ Exercise not found in box for workoutId: ${_currentItem!.workoutId}');
      return;
    }

    print('[ProgramRunning] Current exercise: "${exercise.name}"');
    print('[ProgramRunning] Exercise ID: ${exercise.id}');
    print('[ProgramRunning] Exercise audioFile in model: "${exercise.audioFile}"');
    print('[ProgramRunning] audioFile is null: ${exercise.audioFile == null}');
    print('[ProgramRunning] audioFile is empty: ${exercise.audioFile?.isEmpty ?? true}');

    final isBreak = exercise.name.toLowerCase() == 'break' ||
        exercise.name.toLowerCase() == 'rest';

    if (isBreak) {
      print('[ProgramRunning] Exercise is a BREAK');
      // Play break sound using exercise audioFile if available, otherwise use playBreakSound
      if (exercise.audioFile != null && exercise.audioFile!.isNotEmpty) {
        print('[ProgramRunning] ✓ Break exercise has audioFile in model: "${exercise.audioFile}"');
        print('[ProgramRunning] Playing break audio from exercise.audioFile');
        await _audioService.playExerciseAudio(exercise.audioFile);
      } else {
        print('[ProgramRunning] ✗ Break exercise has NO audioFile in model');
        print('[ProgramRunning] Falling back to default break sound');
        await _audioService.playBreakSound();
      }
      // Wait a bit for break sound to start
      await Future.delayed(Duration(milliseconds: 500));

      // Announce next exercise if available
      if (_currentIndex < _workoutItems.length - 1) {
        final nextItem = _workoutItems[_currentIndex + 1];
        final nextExercise = exercisesBox.get(nextItem.workoutId);
        if (nextExercise != null) {
          print('[ProgramRunning] Next exercise after break: "${nextExercise.name}"');
          print('[ProgramRunning] Next exercise audioFile: "${nextExercise.audioFile}"');
          if (nextExercise.audioFile != null && nextExercise.audioFile!.isNotEmpty) {
            print('[ProgramRunning] Playing next exercise audio after break');
            // Wait a bit more before playing next exercise audio
            await Future.delayed(Duration(milliseconds: 500));
            await _audioService.playExerciseAudio(nextExercise.audioFile);
          } else {
            print('[ProgramRunning] ✗ Next exercise has no audioFile, skipping announcement');
          }
        }
      }
    } else {
      print('[ProgramRunning] Exercise is a REGULAR exercise');
      // Play exercise audio immediately when starting the exercise
      if (exercise.audioFile != null && exercise.audioFile!.isNotEmpty) {
        print('[ProgramRunning] ✓ Exercise has audioFile in model: "${exercise.audioFile}"');
        print('[ProgramRunning] Attempting to play exercise audio for: "${exercise.name}"');
        await _audioService.playExerciseAudio(exercise.audioFile);
      } else {
        print('[ProgramRunning] ✗ Exercise "${exercise.name}" has NO audioFile set in model');
        print('[ProgramRunning] Cannot play exercise audio - audioFile is missing');
      }
    }
  }

  void _restartWorkout() {
    _timer?.cancel();

    setState(() {
      // Reset only the current exercise timer
      _remainingSeconds = _workoutItems[_currentIndex].time;
      _isPaused = false;
      _hasPlayed5SecondWarning = false;
      _playedCountdownNumbers.clear();
    });

    // Play audio for the current exercise
    _loadCurrentExerciseAndPlayAudio();

    if (_hasStarted) {
      _ensureTickTimer();
    }
  }

  void _skipToNext() {
    _moveToNextExercise();
  }

  void _completeWorkout() async {
    _timer?.cancel();
    widget.program.recordCompletion();
    
    // Play workout complete audio
    await _audioService.playWorkoutComplete();
    
    // Wait a moment for the audio to play, then navigate back
    await Future.delayed(Duration(milliseconds: 500));
    
    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate completion
    }
  }

  void _exitWorkout() {
    _timer?.cancel();
    Navigator.pop(context, false);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTotalTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
    return '0:${secs.toString().padLeft(2, '0')}';
  }

  int _get10SecondIntervalCount() {
    // Calculate how many 10-second intervals have passed
    final totalTime = _workoutItems[_currentIndex].time;
    final maxIntervals = (totalTime / 10).ceil();
    return ((_workoutItems[_currentIndex].time - _remainingSeconds) ~/ 10).clamp(0, maxIntervals);
  }

  int _getMaxIntervalCount() {
    // Calculate maximum number of 10-second intervals for current exercise
    final totalTime = _workoutItems[_currentIndex].time;
    return (totalTime / 10).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with exit and total time
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isPaused || !_hasStarted)
                    TextButton.icon(
                      onPressed: _exitWorkout,
                      icon: Icon(Icons.exit_to_app),
                      label: Text('Exit'),
                    )
                  else
                    SizedBox(width: 80), // Spacer for alignment
                  Text(
                    _formatTotalTime(_totalElapsedSeconds),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Main exercise display
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_hasStarted) {
                    _startTimer();
                    // Audio will be played in _startTimer via _loadCurrentExerciseAndPlayAudio
                  } else {
                    if (_isPaused) {
                      _resumeTimer();
                    } else {
                      _pauseTimer();
                    }
                  }
                },
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Current exercise image
                        Expanded(
                          flex: 3,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Use the smaller dimension to ensure square
                              final size = constraints.maxWidth < constraints.maxHeight
                                  ? constraints.maxWidth
                                  : constraints.maxHeight;
                              return ValueListenableBuilder(
                                valueListenable:
                                    Hive.box<ExerciseModel>('exercises').listenable(),
                                builder: (context, Box<ExerciseModel> box, _) {
                                  if (_currentItem == null) {
                                    return SizedBox();
                                  }

                                  final exercise = box.get(_currentItem!.workoutId);
                                  if (exercise == null) {
                                    return SizedBox();
                                  }

                                  return Center(
                                    child: Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: AppColorPalette.white,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: WorkoutIconWidget(
                                          imageUrl: exercise.imageUrl,
                                          size: null, // Let it fill the container
                                          backgroundColor: AppColorPalette.white,
                                          placeholder: Icon(
                                            Icons.fitness_center,
                                            size: 80,
                                            color: AppColorPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 24),
                        // Exercise name
                        ValueListenableBuilder(
                          valueListenable:
                              Hive.box<ExerciseModel>('exercises').listenable(),
                          builder: (context, Box<ExerciseModel> box, _) {
                            if (_currentItem == null) {
                              return SizedBox();
                            }

                            final exercise = box.get(_currentItem!.workoutId);
                            if (exercise == null) {
                              return SizedBox();
                            }

                            return Text(
                              exercise.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        SizedBox(height: 24),
                        // Remaining seconds
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        // 10-second interval indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_getMaxIntervalCount(), (index) {
                            final filledCount = _get10SecondIntervalCount();
                            final isFilled = index < filledCount;
                            return Container(
                              width: 40,
                              height: 8,
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isFilled
                                    ? Theme.of(context).primaryColor
                                    : AppColorPalette.grey300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 24),
                        // Pause/Resume indicator
                        if (_hasStarted)
                          Text(
                            _isPaused ? 'Tap to Resume' : 'Tap to Pause',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColorPalette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Controls (only shown when paused or not started)
            if (_isPaused || !_hasStarted) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _restartWorkout,
                      icon: Icon(Icons.refresh),
                      label: Text('Restart'),
                    ),
                    TextButton.icon(
                      onPressed: _skipToNext,
                      icon: Icon(Icons.skip_next),
                      label: Text('Skip to Next'),
                    ),
                  ],
                ),
              ),
              // Next 3 exercises preview
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Exercises',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    ValueListenableBuilder(
                      valueListenable:
                          Hive.box<ExerciseModel>('exercises').listenable(),
                      builder: (context, Box<ExerciseModel> box, _) {
                        final nextExercises = <Widget?>[];
                        int foundCount = 0;
                        
                        // Look ahead to find next 3 non-break exercises
                        for (int i = 1; i < _workoutItems.length && foundCount < 3; i++) {
                          final nextIndex = _currentIndex + i;
                          if (nextIndex < _workoutItems.length) {
                            final nextItem = _workoutItems[nextIndex];
                            final exercise = box.get(nextItem.workoutId);
                            
                            // Skip break exercises
                            if (exercise != null) {
                              final isBreak = exercise.name.toLowerCase() == 'break' ||
                                  exercise.name.toLowerCase() == 'rest';
                              
                              if (!isBreak) {
                                nextExercises.add(
                                  _buildNextExercisePreview(
                                    exercise,
                                    nextItem.time,
                                    nextIndex,
                                  ),
                                );
                                foundCount++;
                              }
                            }
                          }
                        }

                        // Always show 3 spaces (fill with blank spaces if needed)
                        while (nextExercises.length < 3) {
                          nextExercises.add(_buildBlankExerciseSpace());
                        }

                        return Row(
                          children: nextExercises.cast<Widget>(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlankExerciseSpace() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColorPalette.grey200,
                  border: Border.all(
                    color: AppColorPalette.grey300,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.remove,
                    color: AppColorPalette.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '',
              style: TextStyle(
                fontSize: 10,
                color: AppColorPalette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '',
              style: TextStyle(
                fontSize: 8,
                color: AppColorPalette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextExercisePreview(ExerciseModel exercise, int time, int targetIndex) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _moveToExerciseIndex(targetIndex);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColorPalette.white,
                    border: Border.all(
                      color: AppColorPalette.grey300,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: WorkoutIconWidget(
                        imageUrl: exercise.imageUrl,
                        size: null, // Let it fill the container
                        backgroundColor: AppColorPalette.white,
                        placeholder: Icon(
                          Icons.fitness_center,
                          size: 24,
                          color: AppColorPalette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                exercise.name,
                style: TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                '${time}s',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColorPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/utils/audio_utils.dart';

class RecordingButtonWidget extends StatefulWidget {
  final Function(EnhancedAudioModel) onRecordingComplete;
  final VoidCallback onReset;
  final bool hasRecording;

  const RecordingButtonWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onReset,
    required this.hasRecording,
  });

  @override
  State<RecordingButtonWidget> createState() => _RecordingButtonWidgetState();
}

class _RecordingButtonWidgetState extends State<RecordingButtonWidget>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _stopRecordingInProgress = false;
  double _smoothedMicLevel = 0;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  Timer? _levelTimer;

  final List<double> _audioLevels = [];

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
        _smoothedMicLevel = 0;
      });

      _pulseController.repeat(reverse: true);
      _startTimer();
      _startLevelMonitoring();
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_stopRecordingInProgress || !_isRecording) return;
    _stopRecordingInProgress = true;
    _timer?.cancel();
    _levelTimer?.cancel();
    _pulseController.stop();
    try {
      final path = await _recorder.stop();

      if (path != null) {
        final audioModel = EnhancedAudioModel(
          filePath: path,
          fileName: path.split('/').last,
          createdAt: DateTime.now(),
          durationMs: _recordingDuration.inMilliseconds,
          fileSizeBytes: 0,
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

      if (mounted) {
        setState(() {
          _isRecording = false;
          _smoothedMicLevel = 0;
        });
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _smoothedMicLevel = 0;
        });
      }
    } finally {
      _stopRecordingInProgress = false;
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
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording || !mounted) return;
      try {
        final amplitude = await _recorder.getAmplitude();
        final normalized = normalizeMicDb(amplitude.current);

        if (!mounted || !_isRecording) return;
        setState(() {
          _smoothedMicLevel = _smoothedMicLevel * 0.74 + normalized * 0.26;
          _audioLevels.add(_smoothedMicLevel);
          if (_audioLevels.length > 50) {
            _audioLevels.removeAt(0);
          }
        });
      } catch (e) {
        // Handle amplitude error silently
      }
    });
  }

  Widget _buildAudioLevelsVisualization(Color waveformAccent) {
    if (!_isRecording) return SizedBox.shrink();

    return IgnorePointer(
      child: Positioned.fill(
        child: CustomPaint(
          painter: _AudioLevelsPainter(_audioLevels, waveformAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final errorColor = AppColorPalette.error;
        final successColor = AppColorPalette.success;
        final infoColor = AppColorPalette.info;
        final micHot = AppColorPalette.warning;
        final rawLevel = _smoothedMicLevel.clamp(0.0, 1.0);
        final intensity =
            pow(rawLevel, 0.34).toDouble().clamp(0.0, 1.0);
        final recordingAccent = _isRecording
            ? Color.lerp(errorColor, micHot, intensity)!
            : errorColor;
        final recordingFill = _isRecording
            ? Color.lerp(
                errorColor.withValues(alpha: 0.03),
                micHot.withValues(alpha: 0.12 + 0.38 * intensity),
                intensity,
              )!
            : errorColor.withValues(alpha: 0.1);
        final recordingBorder = _isRecording ? recordingAccent : errorColor;
        final borderWidth = _isRecording ? 2.0 + 5.5 * intensity : 2.0;

        return Transform.scale(
          scale: _isRecording ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                    ? recordingFill
                    : widget.hasRecording
                    ? successColor.withValues(alpha: 0.1)
                    : infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isRecording && intensity > 0.12
                    ? [
                        BoxShadow(
                          color: recordingAccent.withValues(
                            alpha: 0.15 + 0.55 * intensity,
                          ),
                          blurRadius: 4 + 14 * intensity,
                          spreadRadius: -0.5,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: _isRecording
                      ? recordingBorder
                      : widget.hasRecording
                      ? successColor
                      : infoColor,
                  width: borderWidth,
                ),
              ),
              child: Stack(
                children: [
                  _buildAudioLevelsVisualization(recordingAccent),
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
                              ? recordingAccent
                              : widget.hasRecording
                                  ? successColor
                                  : infoColor,
                        ),
                        if (_isRecording) ...[
                          SizedBox(height: 4),
                          Text(
                            '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: recordingAccent,
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
  final Color accent;

  _AudioLevelsPainter(this.levels, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final paint = Paint()
      ..color = accent.withValues(alpha: 0.35)
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

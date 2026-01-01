import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';

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
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  Timer? _levelTimer;

  // Audio levels for visualization
  // ignore: unused_field
  double _currentLevel = 0.0;
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

      setState(() {
        _isRecording = false;
        _currentLevel = 0.0;
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
          _currentLevel = level;
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

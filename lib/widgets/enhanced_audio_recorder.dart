// lib/widgets/enhanced_audio_recorder.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class EnhancedAudioRecorder extends StatefulWidget {
  final Function(EnhancedAudioModel) onRecordingComplete;
  final String? category;

  const EnhancedAudioRecorder({
    super.key,
    required this.onRecordingComplete,
    this.category,
  });

  @override
  State<EnhancedAudioRecorder> createState() => _EnhancedAudioRecorderState();
}

class _EnhancedAudioRecorderState extends State<EnhancedAudioRecorder>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;

  // Waveform visualization
  final List<double> _realtimeWaveform = [];
  late AnimationController _waveformController;
  late Animation<double> _waveformAnimation;

  // Audio level monitoring
  double _currentLevel = 0.0;
  Timer? _levelTimer;

  // Settings
  AudioSettingsModel? _audioSettings;

  // Recording metadata
  String? _title;
  String? _description;
  List<String> _tags = [];
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAudioSettings();
    _initializeAnimations();
  }

  void _loadAudioSettings() {
    final box = Hive.box<AudioSettingsModel>('audioSettings');
    _audioSettings = box.get('settings') ?? AudioSettingsModel();
  }

  void _initializeAnimations() {
    _waveformController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );

    _waveformAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveformController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelTimer?.cancel();
    _waveformController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final format = _audioSettings?.exportFormat ?? 'm4a';
      final filePath = '${dir.path}/audio_$timestamp.$format';

      // Configure recording based on settings
      final config = _getRecordConfig();

      await _recorder.start(config, path: filePath);

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _realtimeWaveform.clear();
      });

      _startTimer();
      _startLevelMonitoring();
      _waveformController.repeat();
    } else {
      _showPermissionDialog();
    }
  }

  RecordConfig _getRecordConfig() {
    if (_audioSettings == null) return RecordConfig();

    AudioEncoder encoder;
    switch (_audioSettings!.codec) {
      case 'opus':
        encoder = AudioEncoder.opus;
        break;
      case 'wav':
        encoder = AudioEncoder.wav;
        break;
      default:
        encoder = AudioEncoder.aacLc;
    }

    return RecordConfig(
      encoder: encoder,
      bitRate: _audioSettings!.bitRate * 1000, // Convert to bps
      sampleRate: _audioSettings!.sampleRate,
      numChannels: _audioSettings!.channels,
      autoGain: _audioSettings!.enableAutoGain,
      echoCancel: _audioSettings!.enableNoiseReduction,
      noiseSuppress: _audioSettings!.enableNoiseReduction,
    );
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    setState(() => _isPaused = true);
    _timer?.cancel();
    _levelTimer?.cancel();
    _waveformController.stop();
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    setState(() => _isPaused = false);
    _startTimer();
    _startLevelMonitoring();
    _waveformController.repeat();
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    _timer?.cancel();
    _levelTimer?.cancel();
    _waveformController.stop();

    if (path != null) {
      await _saveRecording(path);
    }
  }

  Future<void> _saveRecording(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    // Get file info
    final stat = await file.stat();
    final fileName = filePath.split('/').last;

    // Create enhanced audio model
    final audioModel = EnhancedAudioModel(
      filePath: filePath,
      fileName: fileName,
      createdAt: DateTime.now(),
      durationMs: _recordingDuration.inMilliseconds,
      fileSizeBytes: stat.size,
      format: _audioSettings?.exportFormat ?? 'm4a',
      bitRate: _audioSettings?.bitRate ?? 128,
      sampleRate: _audioSettings?.sampleRate ?? 44100,
      channels: _audioSettings?.channels ?? 1,
      title: _title?.isNotEmpty == true ? _title : null,
      description: _description?.isNotEmpty == true ? _description : null,
      tags: List.from(_tags),
      category: widget.category,
      waveformData: List.from(_realtimeWaveform),
      waveformSamples: _realtimeWaveform.length,
    );

    // Save to Hive database
    final box = Hive.box<EnhancedAudioModel>('audioFiles');
    await box.add(audioModel);

    // Reset state
    _resetRecording();

    // Notify parent
    widget.onRecordingComplete(audioModel);

    // Show success message
    if (mounted) {
      showAppSnack(
      context,
      text: 'Recording saved successfully!',
    );
    }
  }

  void _resetRecording() {
    setState(() {
      _recordingDuration = Duration.zero;
      _realtimeWaveform.clear();
      _currentLevel = 0.0;
    });

    _titleController.clear();
    _descriptionController.clear();
    _tagController.clear();
    _title = null;
    _description = null;
    _tags.clear();
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
    _levelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _updateAudioLevel();
    });
  }

  void _updateAudioLevel() {
    // Simulate audio level (in real implementation, you'd get actual levels)
    final random = Random();
    setState(() {
      _currentLevel = _isRecording && !_isPaused
          ? random.nextDouble() * 0.8 + 0.1
          : 0.0;

      // Add to waveform data
      if (_realtimeWaveform.length > 200) {
        _realtimeWaveform.removeAt(0);
      }
      _realtimeWaveform.add(_currentLevel);
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Microphone Permission'),
        content: Text('Please grant microphone permission to record audio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMetadataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recording Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter recording title',
                ),
                onChanged: (value) => _title = value,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter description',
                ),
                maxLines: 3,
                onChanged: (value) => _description = value,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Add tags separated by commas',
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _tags = value.split(',').map((e) => e.trim()).toList();
                    });
                  }
                },
              ),
              if (_tags.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          onDeleted: () {
                            setState(() => _tags.remove(tag));
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (_tagController.text.isNotEmpty) {
                _tags = _tagController.text
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 16),
            _buildWaveformVisualization(),
            SizedBox(height: 16),
            _buildTimerAndLevel(),
            SizedBox(height: 16),
            _buildControls(),
            if (_isRecording) ...[
              SizedBox(height: 16),
              _buildMetadataPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _isRecording ? Icons.fiber_manual_record : Icons.mic,
          color: _isRecording ? Colors.red : Colors.grey,
          size: 32,
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRecording
                    ? (_isPaused ? 'Recording Paused' : 'Recording...')
                    : 'Ready to Record',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_audioSettings != null)
                Text(
                  '${_audioSettings!.qualityDescription} • ${_audioSettings!.codec.toUpperCase()}',
                  style: TextStyle(color: AppColorPalette.textSecondary),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: _showMetadataDialog,
          tooltip: 'Add details',
        ),
      ],
    );
  }

  Widget _buildWaveformVisualization() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedBuilder(
        animation: _waveformAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: RealtimeWaveformPainter(
              waveformData: _realtimeWaveform,
              isRecording: _isRecording && !_isPaused,
              color: Theme.of(context).primaryColor,
              animationValue: _waveformAnimation.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimerAndLevel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Recording Timer
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isRecording ? Colors.red : AppColorPalette.textSecondary,
            ),
          ),
        ),

        // Audio Level Indicator
        Column(
          children: [
            Text(
              'Level',
              style: TextStyle(fontSize: 12, color: AppColorPalette.textSecondary),
            ),
            SizedBox(height: 4),
            Container(
              width: 100,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _currentLevel,
                child: Container(
                  decoration: BoxDecoration(
                    color: _currentLevel > 0.8
                        ? Colors.red
                        : _currentLevel > 0.5
                        ? Colors.orange
                        : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel/Reset
        if (_isRecording)
          IconButton(
            icon: Icon(Icons.stop, color: Colors.red),
            iconSize: 32,
            onPressed: _stopRecording,
          )
        else
          IconButton(
            icon: Icon(Icons.refresh),
            iconSize: 32,
            onPressed: _resetRecording,
          ),

        // Pause/Resume
        if (_isRecording)
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            iconSize: 32,
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
          ),

        // Record/Stop
        FloatingActionButton(
          heroTag: "audio_recorder_record_stop",
          onPressed: _isRecording ? _stopRecording : _startRecording,
          backgroundColor: _isRecording
              ? Colors.red
              : Theme.of(context).primaryColor,
          child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 32),
        ),
      ],
    );
  }

  Widget _buildMetadataPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_title?.isNotEmpty == true)
            Text(
              'Title: $_title',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          if (_description?.isNotEmpty == true)
            Text('Description: $_description'),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 4,
              children: _tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag, style: TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          if (_title?.isEmpty != false &&
              _description?.isEmpty != false &&
              _tags.isEmpty)
            Text(
              'Tap the edit icon to add title, description, and tags',
              style: TextStyle(
                color: AppColorPalette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes % 60);
    final seconds = twoDigits(duration.inSeconds % 60);

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

// Custom painter for real-time waveform
class RealtimeWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final bool isRecording;
  final Color color;
  final double animationValue;

  RealtimeWaveformPainter({
    required this.waveformData,
    required this.isRecording,
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isRecording ? 0.8 : 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    if (waveformData.isEmpty) {
      // Draw a flat line when no data
      canvas.drawLine(
        Offset(0, centerY),
        Offset(width, centerY),
        paint..color = color.withValues(alpha: 0.1),
      );
      return;
    }

    final stepWidth = width / max(waveformData.length, 100);

    for (int i = 0; i < waveformData.length; i++) {
      final x = width - (waveformData.length - i) * stepWidth;
      if (x < 0) continue;

      final amplitude = waveformData[i] * centerY * 0.8;

      // Add slight animation pulse when recording
      final pulseEffect = isRecording
          ? 1.0 + 0.1 * sin(animationValue * pi * 2)
          : 1.0;

      canvas.drawLine(
        Offset(x, centerY - amplitude * pulseEffect),
        Offset(x, centerY + amplitude * pulseEffect),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

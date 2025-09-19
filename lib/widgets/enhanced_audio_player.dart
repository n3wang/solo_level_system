// lib/widgets/enhanced_audio_player.dart
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';

class EnhancedAudioPlayer extends StatefulWidget {
  final EnhancedAudioModel audioModel;
  final VoidCallback onDelete;
  final Function(EnhancedAudioModel)? onEdit;

  const EnhancedAudioPlayer({
    super.key,
    required this.audioModel,
    required this.onDelete,
    this.onEdit,
  });

  @override
  State<EnhancedAudioPlayer> createState() => _EnhancedAudioPlayerState();
}

class _EnhancedAudioPlayerState extends State<EnhancedAudioPlayer>
    with TickerProviderStateMixin {
  final _audioPlayer = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);

  StreamSubscription<void>? _playerStateChangedSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 0.8;
  bool _isPlaying = false;
  bool _showWaveform = true;
  bool _showControls = true;

  late AnimationController _waveformAnimationController;
  late Animation<double> _waveformAnimation;

  AudioSettingsModel? _audioSettings;

  @override
  void initState() {
    super.initState();
    _loadAudioSettings();
    _initializePlayer();
    _initializeAnimations();
  }

  void _loadAudioSettings() {
    final box = Hive.box<AudioSettingsModel>('audioSettings');
    _audioSettings = box.get('settings');
    if (_audioSettings != null) {
      _playbackSpeed = _audioSettings!.playbackSpeed;
      _volume = _audioSettings!.volume;
      _showWaveform = _audioSettings!.showWaveform;
    }
  }

  void _initializePlayer() {
    _playerStateChangedSubscription = _audioPlayer.onPlayerComplete.listen(
      (_) => setState(() => _isPlaying = false),
    );

    _positionSubscription = _audioPlayer.onPositionChanged.listen(
      (position) => setState(() => _position = position),
    );

    _durationSubscription = _audioPlayer.onDurationChanged.listen(
      (duration) => setState(() => _duration = duration),
    );

    _audioPlayer.setSource(
      kIsWeb
          ? ap.UrlSource(widget.audioModel.filePath)
          : ap.DeviceFileSource(widget.audioModel.filePath),
    );

    _audioPlayer.setVolume(_volume);
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _initializeAnimations() {
    _waveformAnimationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _waveformAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveformAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    if (_isPlaying) {
      _waveformAnimationController.repeat();
    }
  }

  @override
  void dispose() {
    _playerStateChangedSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _waveformAnimationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _waveformAnimationController.stop();
    } else {
      await _audioPlayer.resume();
      _waveformAnimationController.repeat();
      // Update play statistics
      widget.audioModel.incrementPlayCount();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    widget.audioModel.lastPlayPosition = position.inMilliseconds;
    widget.audioModel.save();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _audioPlayer.setPlaybackRate(speed);
  }

  void _changeVolume(double volume) {
    setState(() => _volume = volume);
    _audioPlayer.setVolume(volume);
  }

  void _toggleFavorite() {
    widget.audioModel.toggleFavorite();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          _buildHeader(),
          if (_showWaveform) _buildWaveform(),
          _buildProgressBar(),
          if (_showControls) _buildControls(),
          _buildMetadata(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          widget.audioModel.isFavorite ? Icons.favorite : Icons.audiotrack,
          color: Colors.white,
        ),
      ),
      title: Text(
        widget.audioModel.title ?? widget.audioModel.fileName,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.audioModel.durationFormatted} • ${widget.audioModel.qualityDescription}',
          ),
          if (widget.audioModel.tags.isNotEmpty)
            Wrap(
              spacing: 4,
              children: widget.audioModel.tags
                  .take(3)
                  .map(
                    (tag) => Chip(
                      label: Text(tag, style: TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              widget.audioModel.isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: _toggleFavorite,
            color: widget.audioModel.isFavorite ? Colors.red : null,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  widget.onEdit?.call(widget.audioModel);
                  break;
                case 'delete':
                  widget.onDelete();
                  break;
                case 'share':
                  _shareAudio();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return Container(
      height: 60,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: widget.audioModel.hasWaveform
          ? CustomPaint(
              size: Size.infinite,
              painter: WaveformPainter(
                waveformData: widget.audioModel.waveformData!,
                progress: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0.0,
                color: Theme.of(context).primaryColor,
                isPlaying: _isPlaying,
                animation: _waveformAnimation,
              ),
            )
          : _buildGeneratedWaveform(),
    );
  }

  Widget _buildGeneratedWaveform() {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: GeneratedWaveformPainter(
            progress: _duration.inMilliseconds > 0
                ? _position.inMilliseconds / _duration.inMilliseconds
                : 0.0,
            color: Theme.of(context).primaryColor,
            isPlaying: _isPlaying,
            animationValue: _waveformAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(_formatDuration(_position)),
          Expanded(
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (_duration.inMilliseconds * value).round(),
                );
                _seekTo(position);
              },
            ),
          ),
          Text(_formatDuration(_duration)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Speed Control
          PopupMenuButton<double>(
            child: Chip(
              label: Text('${_playbackSpeed}x'),
              avatar: Icon(Icons.speed, size: 16),
            ),
            onSelected: _changeSpeed,
            itemBuilder: (context) => [
              PopupMenuItem(value: 0.5, child: Text('0.5x')),
              PopupMenuItem(value: 0.75, child: Text('0.75x')),
              PopupMenuItem(value: 1.0, child: Text('1.0x')),
              PopupMenuItem(value: 1.25, child: Text('1.25x')),
              PopupMenuItem(value: 1.5, child: Text('1.5x')),
              PopupMenuItem(value: 2.0, child: Text('2.0x')),
            ],
          ),

          // Seek Backward
          IconButton(
            icon: Icon(Icons.replay_10),
            onPressed: () {
              final newPosition = _position - Duration(seconds: 10);
              _seekTo(
                newPosition < Duration.zero ? Duration.zero : newPosition,
              );
            },
          ),

          // Play/Pause
          FloatingActionButton(
            mini: true,
            onPressed: _togglePlayback,
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          ),

          // Seek Forward
          IconButton(
            icon: Icon(Icons.forward_10),
            onPressed: () {
              final newPosition = _position + Duration(seconds: 10);
              _seekTo(newPosition > _duration ? _duration : newPosition);
            },
          ),

          // Volume Control
          PopupMenuButton<double>(
            child: Chip(
              label: Text('${(_volume * 100).round()}%'),
              avatar: Icon(Icons.volume_up, size: 16),
            ),
            onSelected: _changeVolume,
            itemBuilder: (context) => [
              PopupMenuItem(value: 0.0, child: Text('Mute')),
              PopupMenuItem(value: 0.25, child: Text('25%')),
              PopupMenuItem(value: 0.5, child: Text('50%')),
              PopupMenuItem(value: 0.75, child: Text('75%')),
              PopupMenuItem(value: 1.0, child: Text('100%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return ExpansionTile(
      title: Text('Details'),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetadataRow(
                'File Size',
                widget.audioModel.fileSizeFormatted,
              ),
              _buildMetadataRow(
                'Format',
                widget.audioModel.format.toUpperCase(),
              ),
              _buildMetadataRow(
                'Bit Rate',
                '${widget.audioModel.bitRate} kbps',
              ),
              _buildMetadataRow(
                'Sample Rate',
                '${widget.audioModel.sampleRate} Hz',
              ),
              _buildMetadataRow(
                'Channels',
                widget.audioModel.channels == 2 ? 'Stereo' : 'Mono',
              ),
              _buildMetadataRow('Play Count', '${widget.audioModel.playCount}'),
              if (widget.audioModel.hasBeenPlayed)
                _buildMetadataRow(
                  'Last Played',
                  widget.audioModel.lastPlayedAt.toString(),
                ),
              if (widget.audioModel.description != null)
                _buildMetadataRow(
                  'Description',
                  widget.audioModel.description!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  void _shareAudio() {
    // Implement sharing functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Share functionality coming soon!')));
  }
}

// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color color;
  final bool isPlaying;
  final Animation<double> animation;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.color,
    required this.isPlaying,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    final stepWidth = width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * stepWidth;
      final amplitude = waveformData[i] * centerY;

      final currentPaint = (x / width) <= progress ? progressPaint : paint;

      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Generated waveform painter for files without waveform data
class GeneratedWaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isPlaying;
  final double animationValue;

  GeneratedWaveformPainter({
    required this.progress,
    required this.color,
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    final barCount = 50;
    final stepWidth = width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * stepWidth;
      final normalizedX = i / barCount;

      // Generate pseudo-random amplitude based on position and animation
      final amplitude =
          sin(normalizedX * pi * 4 + animationValue * pi * 2) *
          centerY *
          0.5 *
          (0.5 + 0.5 * sin(normalizedX * pi * 8));

      final currentPaint = (x / width) <= progress ? progressPaint : paint;

      canvas.drawLine(
        Offset(x, centerY - amplitude.abs()),
        Offset(x, centerY + amplitude.abs()),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

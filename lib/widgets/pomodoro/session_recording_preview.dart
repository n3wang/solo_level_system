import 'dart:async';
import 'dart:math' show max;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';

/// Compact play/pause preview for a session recording before log submit.
class SessionRecordingPreview extends StatefulWidget {
  final EnhancedAudioModel audio;

  const SessionRecordingPreview({super.key, required this.audio});

  @override
  State<SessionRecordingPreview> createState() =>
      _SessionRecordingPreviewState();
}

class _SessionRecordingPreviewState extends State<SessionRecordingPreview> {
  late final ap.AudioPlayer _player;

  StreamSubscription<ap.PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == ap.PlayerState.playing;
      });
    });

    _posSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _durSub = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });

    final source = kIsWeb
        ? ap.UrlSource(widget.audio.filePath)
        : ap.DeviceFileSource(widget.audio.filePath);
    unawaited(_player.setSource(source));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final state = _player.state;
    if (state == ap.PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (state == ap.PlayerState.paused) {
      await _player.resume();
      return;
    }
    if (state == ap.PlayerState.completed) {
      await _player.seek(Duration.zero);
      await _player.resume();
      return;
    }
    await _player.play(
      kIsWeb
          ? ap.UrlSource(widget.audio.filePath)
          : ap.DeviceFileSource(widget.audio.filePath),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _togglePlayback,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUiSizes.sm,
            vertical: AppUiSizes.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: scheme.primary,
                    size: 36,
                  ),
                  const SizedBox(width: AppUiSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice note',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          '${_fmt(_position)} / ${_duration > Duration.zero ? _fmt(_duration) : _fmt(Duration(milliseconds: widget.audio.durationMs))}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUiSizes.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0 ? progress : null,
                  minHeight: 4,
                  backgroundColor:
                      scheme.outlineVariant.withValues(alpha: 0.35),
                  color: scheme.primary,
                ),
              ),
              if (widget.audio.waveformData != null &&
                  widget.audio.waveformData!.isNotEmpty) ...[
                const SizedBox(height: AppUiSizes.sm),
                SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _MiniWaveformPainter(
                      widget.audio.waveformData!,
                      scheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  _MiniWaveformPainter(this.levels, this.accent);

  final List<double> levels;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final take = levels.length > 48 ? 48 : levels.length;
    final start = levels.length - take;
    final barW = size.width / take;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeWidth = max(1.0, barW * 0.35)
      ..strokeCap = StrokeCap.round;

    final cy = size.height / 2;
    for (var i = 0; i < take; i++) {
      final v = levels[start + i].clamp(0.0, 1.0);
      final h = v * size.height * 0.85;
      final x = i * barW + barW / 2;
      canvas.drawLine(
        Offset(x, cy - h / 2),
        Offset(x, cy + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.accent != accent;
}

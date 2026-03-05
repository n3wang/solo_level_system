import 'package:flutter/material.dart';
import '../../constants/pomodoro_constants.dart';

class CompactMusicWidget extends StatefulWidget {
  final bool allowMusic;
  final String? currentlyPlayingTrack;
  final VoidCallback onToggleMusic;
  final VoidCallback onChangeTrack;

  const CompactMusicWidget({
    super.key,
    required this.allowMusic,
    required this.onToggleMusic,
    required this.onChangeTrack,
    this.currentlyPlayingTrack,
  });

  @override
  State<CompactMusicWidget> createState() => _CompactMusicWidgetState();
}

class _CompactMusicWidgetState extends State<CompactMusicWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _feedbackController;
  late final Animation<double> _shakeX;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.02), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _feedbackController, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant CompactMusicWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTrack = oldWidget.currentlyPlayingTrack;
    final newTrack = widget.currentlyPlayingTrack;
    final hasTrackChanged =
        widget.allowMusic &&
        oldTrack != null &&
        newTrack != null &&
        oldTrack != newTrack &&
        newTrack != 'Unknown Track';
    if (hasTrackChanged) {
      _runTrackChangeFeedback();
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _runTrackChangeFeedback() {
    _feedbackController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Hide widget if music is allowed but no track is available
    if (widget.allowMusic &&
        (widget.currentlyPlayingTrack == null ||
            widget.currentlyPlayingTrack == 'Unknown Track')) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onToggleMusic,
      onHorizontalDragEnd: (details) {
        // Swipe left/right to change track
        if (details.velocity.pixelsPerSecond.dx.abs() >
            PomodoroConstants.swipeVelocityThreshold) {
          if (widget.allowMusic) {
            _runTrackChangeFeedback();
            widget.onChangeTrack();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _feedbackController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeX.value, 0),
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.allowMusic
                ? Colors.green.withValues(
                    alpha: PomodoroConstants.containerOpacity,
                  )
                : Colors.grey.withValues(
                    alpha: PomodoroConstants.containerOpacity,
                  ),
            borderRadius: BorderRadius.circular(
              PomodoroConstants.smallBorderRadius,
            ),
            border: Border.all(
              color: widget.allowMusic ? Colors.green : Colors.grey,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.allowMusic ? Icons.music_note : Icons.volume_off,
                    size: 16,
                    color: widget.allowMusic ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: PomodoroConstants.elementSpacing),
                  Flexible(
                    child: Text(
                      widget.allowMusic
                          ? widget.currentlyPlayingTrack!
                          : 'Music Muted',
                      style: TextStyle(
                        fontSize: PomodoroConstants.musicWidgetFontSize,
                        fontWeight: FontWeight.w500,
                        color: widget.allowMusic ? Colors.green : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to ${widget.allowMusic ? 'Mute' : 'Unmute'} • ← → Swipe for Random Track',
                style: TextStyle(
                  fontSize: PomodoroConstants.musicInstructionFontSize,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

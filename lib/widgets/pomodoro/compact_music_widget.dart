import 'package:flutter/material.dart';
import '../../constants/pomodoro_constants.dart';

class CompactMusicWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Hide widget if music is allowed but no track is available
    if (allowMusic &&
        (currentlyPlayingTrack == null ||
            currentlyPlayingTrack == 'Unknown Track')) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onToggleMusic,
      onHorizontalDragEnd: (details) {
        // Swipe left/right to change track
        if (details.velocity.pixelsPerSecond.dx.abs() >
            PomodoroConstants.swipeVelocityThreshold) {
          if (allowMusic) {
            onChangeTrack();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: allowMusic
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
            color: allowMusic ? Colors.green : Colors.grey,
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
                  allowMusic ? Icons.music_note : Icons.volume_off,
                  size: 16,
                  color: allowMusic ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: PomodoroConstants.elementSpacing),
                Flexible(
                  child: Text(
                    allowMusic ? currentlyPlayingTrack! : 'Music Muted',
                    style: TextStyle(
                      fontSize: PomodoroConstants.musicWidgetFontSize,
                      fontWeight: FontWeight.w500,
                      color: allowMusic ? Colors.green : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to ${allowMusic ? 'Mute' : 'Unmute'} • ← → Swipe for Random Track',
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import '../../constants/pomodoro_constants.dart';
import '../../utils/pomodoro_sizing.dart';
import 'session_squares_widget.dart';

class PomodoroTimerWidget extends StatelessWidget {
  final int remainingSeconds;
  final bool isRunning;
  final bool onBreak;
  final bool canSubmitLog;
  final int countCompletedToday;
  final VoidCallback? onTap;
  final Function(DragEndDetails)? onVerticalDragEnd;
  final BackgroundMusicService backgroundMusicService;

  const PomodoroTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.isRunning,
    required this.onBreak,
    required this.canSubmitLog,
    required this.countCompletedToday,
    required this.backgroundMusicService,
    this.onTap,
    this.onVerticalDragEnd,
  });

  String _getInstructionText() {
    if (isRunning) {
      return onBreak ? 'Break Time - Tap to Stop' : 'Focus Time - Tap to Stop';
    } else if (canSubmitLog) {
      return 'Session Complete - Tap to Submit!';
    } else {
      return 'Tap to Start • ↑ Finish • ↓ Reset';
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumSize = PomodoroSizing.getAlbumContainerSize(context);
    final fontSize = PomodoroSizing.getTimerFontSize(context);

    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: onVerticalDragEnd,
      child: SizedBox(
        width: albumSize,
        height: albumSize,
        child: Stack(
          children: [
            // Album background image
            Container(
              width: albumSize,
              height: albumSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  PomodoroConstants.borderRadius,
                ),
                border: Border.all(
                  color: isRunning ? Colors.red : Colors.green,
                  width: PomodoroConstants.borderWidth,
                ),
                image:
                    backgroundMusicService.currentTrack?.albumImagePath != null
                    ? DecorationImage(
                        image: AssetImage(
                          backgroundMusicService.currentTrack!.albumImagePath!,
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
                color:
                    backgroundMusicService.currentTrack?.albumImagePath == null
                    ? (isRunning
                          ? Colors.red.withValues(
                              alpha: PomodoroConstants.containerOpacity,
                            )
                          : Colors.green.withValues(
                              alpha: PomodoroConstants.containerOpacity,
                            ))
                    : null,
              ),
            ),
            // Timer overlay with semi-transparent background
            Container(
              width: albumSize,
              height: albumSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  PomodoroConstants.borderRadius,
                ),
                color: Colors.black.withValues(
                  alpha: PomodoroConstants.backgroundOpacity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    PomodoroSizing.formatTime(remainingSeconds),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: PomodoroConstants.shadowBlurRadius,
                          color: Colors.black,
                          offset: const Offset(
                            PomodoroConstants.shadowOffset,
                            PomodoroConstants.shadowOffset,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PomodoroConstants.elementSpacing),
                  Text(
                    _getInstructionText(),
                    style: const TextStyle(
                      fontSize: PomodoroConstants.timerInstructionFontSize,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                          blurRadius: PomodoroConstants.smallShadowBlurRadius,
                          color: Colors.black,
                          offset: Offset(
                            PomodoroConstants.smallShadowOffset,
                            PomodoroConstants.smallShadowOffset,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PomodoroConstants.elementSpacing),
                  SessionSquaresWidget(completedSessions: countCompletedToday),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

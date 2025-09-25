import 'package:flutter/material.dart';
import 'package:solo_level_system/utils/background_music_service.dart';

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
    Key? key,
    required this.remainingSeconds,
    required this.isRunning,
    required this.onBreak,
    required this.canSubmitLog,
    required this.countCompletedToday,
    required this.backgroundMusicService,
    this.onTap,
    this.onVerticalDragEnd,
  }) : super(key: key);

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getAlbumContainerSize(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final fourtyPercent = screenH * 0.4;
    return fourtyPercent > 200 ? fourtyPercent : 200;
  }

  double _getTimerFontSize(BuildContext context) {
    final containerSize = _getAlbumContainerSize(context);
    return (containerSize / 200) * 48;
  }

  Widget _buildSessionSquares() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: List.generate(
        countCompletedToday,
        (index) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.green, width: 0.5),
          ),
        ),
      ),
    );
  }

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
    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Container(
        width: _getAlbumContainerSize(context),
        height: _getAlbumContainerSize(context),
        child: Stack(
          children: [
            // Album background image
            Container(
              width: _getAlbumContainerSize(context),
              height: _getAlbumContainerSize(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRunning ? Colors.red : Colors.green,
                  width: 2,
                ),
                image: backgroundMusicService.currentTrack?.albumImagePath != null
                    ? DecorationImage(
                        image: AssetImage(backgroundMusicService.currentTrack!.albumImagePath!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: backgroundMusicService.currentTrack?.albumImagePath == null
                    ? (isRunning
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1))
                    : null,
              ),
            ),
            // Timer overlay with semi-transparent background
            Container(
              width: _getAlbumContainerSize(context),
              height: _getAlbumContainerSize(context),
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
                      fontSize: _getTimerFontSize(context),
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
                    _getInstructionText(),
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
                  _buildSessionSquares(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
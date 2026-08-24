import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/constants/pomodoro_constants.dart';
import 'package:solo_level_system/widgets/pomodoro/session_squares_widget.dart';

/// The menu-bar popover's Pomodoro display — a single square, styled after
/// the mobile app's [PomodoroTimerWidget] (tinted border + dark overlay +
/// time + session squares, all inside one tappable square). No separate
/// start/pause/stop buttons: tap the square to toggle, tap the small corner
/// icon to reset.
class CompactTimerDisplay extends StatelessWidget {
  final String formattedTime;
  final bool isRunning;
  final bool onBreak;
  final int completedSessions;
  final String? albumImagePath;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const CompactTimerDisplay({
    super.key,
    required this.formattedTime,
    required this.isRunning,
    required this.onBreak,
    required this.completedSessions,
    this.albumImagePath,
    required this.onToggle,
    required this.onReset,
  });

  String get _instructionText {
    final status = onBreak ? 'Break' : 'Focus';
    return isRunning
        ? '$status Time · Tap to Pause'
        : '$status Time · Tap to Start';
  }

  @override
  Widget build(BuildContext context) {
    final accent = isRunning ? AppColorPalette.error : AppColorPalette.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        return GestureDetector(
          onTap: onToggle,
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        PomodoroConstants.borderRadius,
                      ),
                      border: Border.all(
                        color: accent,
                        width: PomodoroConstants.borderWidth,
                      ),
                      image: albumImagePath != null
                          ? DecorationImage(
                              image: AssetImage(albumImagePath!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: albumImagePath == null
                          ? accent.withValues(
                              alpha: PomodoroConstants.containerOpacity,
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        PomodoroConstants.borderRadius,
                      ),
                      color: Colors.black.withValues(
                        alpha: PomodoroConstants.backgroundOpacity,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: PomodoroConstants.baseFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius:
                                        PomodoroConstants.shadowBlurRadius,
                                    color: Colors.black,
                                    offset: Offset(
                                      PomodoroConstants.shadowOffset,
                                      PomodoroConstants.shadowOffset,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: PomodoroConstants.elementSpacing,
                          ),
                          Text(
                            _instructionText,
                            style: const TextStyle(
                              fontSize:
                                  PomodoroConstants.timerInstructionFontSize,
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                              shadows: [
                                Shadow(
                                  blurRadius:
                                      PomodoroConstants.smallShadowBlurRadius,
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
                          const SizedBox(
                            height: PomodoroConstants.elementSpacing,
                          ),
                          SessionSquaresWidget(
                            completedSessions: completedSessions,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _CornerIconButton(icon: Icons.refresh, onTap: onReset),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CornerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CornerIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

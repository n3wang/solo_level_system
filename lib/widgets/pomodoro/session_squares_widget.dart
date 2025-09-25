import 'package:flutter/material.dart';
import '../../constants/pomodoro_constants.dart';

/// Widget for displaying completed session squares
class SessionSquaresWidget extends StatelessWidget {
  final int completedSessions;

  const SessionSquaresWidget({Key? key, required this.completedSessions})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: PomodoroConstants.sessionSquareSpacing,
      runSpacing: PomodoroConstants.sessionSquareSpacing,
      children: List.generate(
        completedSessions,
        (index) => Container(
          width: PomodoroConstants.sessionSquareSize,
          height: PomodoroConstants.sessionSquareSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              PomodoroConstants.sessionSquareBorderRadius,
            ),
            border: Border.all(
              color: Colors.green,
              width: PomodoroConstants.sessionSquareBorderWidth,
            ),
          ),
        ),
      ),
    );
  }
}

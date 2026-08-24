import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/screens/case_math_screen.dart';
import 'package:solo_level_system/screens/chrono_atlas_screen.dart';
import 'package:solo_level_system/screens/times_tables_screen.dart';

/// A playable mini-game entry for the Games hub and rest-break launcher.
class MiniGameEntry {
  const MiniGameEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.build,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  /// Builds the game screen. [exitLabel] is the summary exit button text.
  final Widget Function({required String exitLabel}) build;
}

/// Central catalog of mini-games. Add new games here so hub + rest random launch stay in sync.
class MiniGames {
  MiniGames._();

  static final _random = Random();

  static const defaultExitLabel = 'Back to games';
  static const workoutExitLabel = 'Back to workout';

  /// All launchable games (geo, history/time, mixed, and future entries).
  static List<MiniGameEntry> get catalog => [
        for (final mode in ChronoAtlasSessionMode.values)
          MiniGameEntry(
            id: mode.highScoreKey,
            title: mode.title,
            subtitle: mode.subtitle,
            icon: mode.hubIcon,
            accent: switch (mode) {
              ChronoAtlasSessionMode.mixed => AppColorPalette.color1,
              ChronoAtlasSessionMode.geo => AppColorPalette.color2,
              ChronoAtlasSessionMode.time => AppColorPalette.color3,
            },
            build: ({required String exitLabel}) => ChronoAtlasScreen(
              sessionMode: mode,
              exitLabel: exitLabel,
            ),
          ),
        MiniGameEntry(
          id: CaseMathScreen.highScoreKey,
          title: 'Case Math',
          subtitle: 'Coffee chain & manufacturing cases',
          icon: Icons.calculate_outlined,
          accent: AppColorPalette.color4,
          build: ({required String exitLabel}) => CaseMathScreen(
            exitLabel: exitLabel,
          ),
        ),
        MiniGameEntry(
          id: TimesTablesScreen.highScoreKey,
          title: 'Times Tables',
          subtitle: 'Race through multiplication facts',
          icon: Icons.grid_on_outlined,
          accent: AppColorPalette.color3,
          build: ({required String exitLabel}) => TimesTablesScreen(
            exitLabel: exitLabel,
          ),
        ),
      ];

  static Future<void> open(
    BuildContext context,
    MiniGameEntry game, {
    String exitLabel = defaultExitLabel,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => game.build(exitLabel: exitLabel),
      ),
    );
  }

  static Future<void> openRandom(
    BuildContext context, {
    String exitLabel = defaultExitLabel,
  }) {
    final games = catalog;
    if (games.isEmpty) return Future.value();
    final game = games[_random.nextInt(games.length)];
    return open(context, game, exitLabel: exitLabel);
  }
}

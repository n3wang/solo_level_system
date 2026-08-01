import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/screens/chrono_atlas_screen.dart';

/// Workout → Game tab hub for mini-games.
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        Text(
          'Games',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColorPalette.textColor,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Short sessions between sets.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColorPalette.textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        Material(
          color: AppColorPalette.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColorPalette.color1.withValues(alpha: 0.2),
              child: Icon(Icons.public, color: AppColorPalette.color1),
            ),
            title: Text(
              'Chrono Atlas',
              style: TextStyle(
                color: AppColorPalette.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Pin the place and year',
              style: TextStyle(color: AppColorPalette.textSecondary),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppColorPalette.textSecondary,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChronoAtlasScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

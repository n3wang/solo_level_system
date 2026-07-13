// lib/widgets/theme_mode_selector_widget.dart
import 'package:flutter/material.dart';
import '../constants/color_palette.dart';

/// Widget to display and select theme mode
/// Shows preview boxes with background and text colors for each theme
class ThemeModeSelectorWidget extends StatelessWidget {
  final String selectedTheme;
  final Function(String) onThemeSelected;

  const ThemeModeSelectorWidget({
    super.key,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  static const Map<String, String> themeNames = {
    'system': 'System',
    'light': 'Light',
    'dark': 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Theme Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: themeNames.entries.map((entry) {
            final themeMode = entry.key;
            final displayName = entry.value;
            final isSelected = selectedTheme == themeMode;
            final themeColors = _getThemeColors(themeMode);

            return GestureDetector(
              onTap: () => onThemeSelected(themeMode),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? AppColorPalette.primary
                        : AppColorPalette.grey300,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? AppColorPalette.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview box showing background and text colors
                    Container(
                      width: 70,
                      height: 45,
                      decoration: BoxDecoration(
                        color: themeColors['background'],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColorPalette.textSecondary,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Background color indicator (larger)
                          Container(
                            width: 50,
                            height: 20,
                            margin: EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: themeColors['background'],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColorPalette.textSecondary,
                                width: 0.5,
                              ),
                            ),
                          ),
                          // Text color indicator (smaller circle)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: themeColors['text'],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColorPalette.textSecondary,
                                width: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    // Theme name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColorPalette.primary
                            : AppColorPalette.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, Color> _getThemeColors(String themeMode) {
    switch (themeMode) {
      case 'light':
        return {
          'background': AppColorPalette.background,
          'text': AppColorPalette.textColor,
        };
      case 'dark':
        return {
          'background': AppColorPalette.backgroundDark,
          'text': AppColorPalette.white,
        };
      case 'system':
      default:
        // For system, show a preview that represents both (use light as default preview)
        return {
          'background': AppColorPalette.background,
          'text': AppColorPalette.textColor,
        };
    }
  }
}

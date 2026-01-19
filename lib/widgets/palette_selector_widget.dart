// lib/widgets/palette_selector_widget.dart
import 'package:flutter/material.dart';
import '../constants/color_palette.dart';

/// Widget to display and select color palettes
/// Shows color rectangles for each palette option
class PaletteSelectorWidget extends StatelessWidget {
  final String selectedPalette;
  final Function(String) onPaletteSelected;

  const PaletteSelectorWidget({
    super.key,
    required this.selectedPalette,
    required this.onPaletteSelected,
  });

  static const Map<String, String> paletteNames = {
    'grayscale': 'Grayscale',
    'creative': 'Creative',
    'pastel': 'Pastel',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Color Palette',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: paletteNames.entries.map((entry) {
            final paletteName = entry.key;
            final displayName = entry.value;
            final isSelected = selectedPalette == paletteName;
            final colors = AppColorPalette.getColorsFromPalette(paletteName);

            return GestureDetector(
              onTap: () => onPaletteSelected(paletteName),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color rectangles
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: colors.map((color) {
                        return Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 6),
                    // Palette name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
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
}

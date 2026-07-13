import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Settings slider with a small rectangular thumb and visible min/max end caps.
class SettingsSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? label;
  final Color? activeColor;

  const SettingsSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChanged,
    this.onChangeEnd,
    this.label,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        activeTrackColor: accent,
        inactiveTrackColor: AppColorPalette.grey300,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        thumbShape: const _RectSliderThumbShape(),
        trackShape: const _SettingsSliderTrackShape(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        valueIndicatorColor: accent,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// Compact rectangle thumb (not a circle).
class _RectSliderThumbShape extends SliderComponentShape {
  const _RectSliderThumbShape();

  static const Size _size = Size(7, 16);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter? labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final color = ColorTween(
      begin: sliderTheme.disabledThumbColor ?? AppColorPalette.grey400,
      end: sliderTheme.thumbColor ?? AppColorPalette.grey800,
    ).evaluate(enableAnimation)!;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: _size.width,
        height: _size.height,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }
}

/// Track with solid end caps so min/max extremes are easy to see.
class _SettingsSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _SettingsSliderTrackShape();

  static const double _capWidth = 2.5;
  static const double _capHeight = 12;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeColor = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    ).evaluate(enableAnimation)!;
    final inactiveColor = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    final capColor = ColorTween(
      begin: AppColorPalette.grey400,
      end: AppColorPalette.grey600,
    ).evaluate(enableAnimation)!;

    final trackRadius = Radius.circular(trackRect.height / 2);
    final isLtr = textDirection == TextDirection.ltr;
    final left = trackRect.left;
    final right = trackRect.right;
    final thumbX = thumbCenter.dx.clamp(left, right);

    // Inactive full track (gives a continuous baseline).
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      Paint()..color = inactiveColor,
    );

    // Active segment.
    final activeRect = isLtr
        ? Rect.fromLTRB(left, trackRect.top, thumbX, trackRect.bottom)
        : Rect.fromLTRB(thumbX, trackRect.top, right, trackRect.bottom);
    if (activeRect.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, trackRadius),
        Paint()..color = activeColor,
      );
    }

    // Min / max end caps — always visible so extremes are identifiable.
    void drawCap(double x) {
      final capRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, trackRect.center.dy),
          width: _capWidth,
          height: _capHeight,
        ),
        Radius.circular(AppUiSizes.buttonRadius / 3),
      );
      canvas.drawRRect(capRect, Paint()..color = capColor);
    }

    drawCap(left);
    drawCap(right);
  }
}

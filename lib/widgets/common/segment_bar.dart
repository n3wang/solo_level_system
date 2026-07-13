import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Compact vertical segment strip.
///
/// Modes:
/// - Exclusive (`fillToSelected: false`): only [selectedIndex] filled
/// - Cumulative (`fillToSelected: true`): fills `0..selectedIndex`
/// - Per-segment ([segmentStates]): each segment has its own fill state
///   (used for schedule days — full / empty / morning / afternoon / evening)
class SegmentBar extends StatelessWidget {
  /// Number of segments.
  final int count;

  /// Active index (0-based). For [fillToSelected], all segments `<= selectedIndex`
  /// are filled. Use `-1` for none selected in exclusive mode.
  /// Ignored when [segmentStates] is set.
  final int selectedIndex;

  /// When true, fills every segment up to [selectedIndex] (volume-style).
  /// When false, only [selectedIndex] is filled (room/project-style).
  final bool fillToSelected;

  /// Per-segment visual state (length should match [count]).
  /// Convention:
  /// - `0` → fully filled
  /// - `1` → empty (outline only)
  /// - `2 .. 1+[partialBandCount]` → fill one vertical band (top → bottom)
  final List<int>? segmentStates;

  /// Number of vertical bands for partial fills (schedule: Morning/Afternoon/Evening).
  final int partialBandCount;

  final ValueChanged<int> onSelected;

  final double segmentWidth;
  final double segmentHeight;
  final double spacing;
  final Color? activeColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final Duration animationDuration;

  const SegmentBar({
    super.key,
    required this.count,
    required this.onSelected,
    this.selectedIndex = -1,
    this.fillToSelected = false,
    this.segmentStates,
    this.partialBandCount = 3,
    this.segmentWidth = 12,
    this.segmentHeight = 24,
    this.spacing = 4,
    this.activeColor,
    this.borderColor,
    this.borderWidth = AppUiSizes.smallBorderWidth,
    this.borderRadius = 3,
    this.animationDuration = const Duration(milliseconds: 140),
  });

  bool _isFullyActive(int index) {
    if (segmentStates != null) return false;
    if (fillToSelected) {
      return selectedIndex >= 0 && index <= selectedIndex;
    }
    return index == selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final fill = activeColor ?? Theme.of(context).colorScheme.primary;
    final stroke = borderColor ?? AppColorPalette.grey800;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(count, (index) {
        final state = segmentStates != null && index < segmentStates!.length
            ? segmentStates![index]
            : (_isFullyActive(index) ? 0 : 1);

        return GestureDetector(
          onTap: () => onSelected(index),
          child: _SegmentCell(
            width: segmentWidth,
            height: segmentHeight,
            state: state,
            bandCount: partialBandCount,
            fillColor: fill,
            borderColor: stroke,
            borderWidth: borderWidth,
            borderRadius: borderRadius,
            duration: animationDuration,
          ),
        );
      }),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  final double width;
  final double height;
  final int state;
  final int bandCount;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Duration duration;

  const _SegmentCell({
    required this.width,
    required this.height,
    required this.state,
    required this.bandCount,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final bands = bandCount < 1 ? 1 : bandCount;
    final bandHeight = height / bands;

    return AnimatedContainer(
      duration: duration,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
              ),
            ),
            if (state == 0)
              Positioned.fill(child: ColoredBox(color: fillColor)),
            if (state >= 2 && state <= bands + 1)
              Positioned(
                top: (state - 2) * bandHeight,
                left: 0,
                right: 0,
                height: bandHeight,
                child: ColoredBox(color: fillColor),
              ),
          ],
        ),
      ),
    );
  }
}

/// Label stacked above a [SegmentBar] (Room / Volume / Project / Schedule).
class LabeledSegmentBar extends StatelessWidget {
  final String label;
  final TextStyle? labelStyle;
  final CrossAxisAlignment alignment;
  final SegmentBar bar;

  const LabeledSegmentBar({
    super.key,
    required this.label,
    required this.bar,
    this.labelStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: labelStyle ?? Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        bar,
      ],
    );
  }
}

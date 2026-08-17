import 'package:solo_level_system/constants/app_ui_sizes.dart';

/// Shared GitHub-style heatmap grid used on overview and character stats.
class HeatmapLayout {
  HeatmapLayout._();

  static const int cellCount = 7;
  static const double gap = 4.0;
  static const double minCellSize = 28.0;
  static const double maxCellSize = 44.0;
  static const double horizontalInset = AppUiSizes.xl * 2;

  /// Character stat chips use the heatmap cell width, this times taller.
  static const double statChipHeightFactor = 1.5;

  /// Square cells with a small gap, centered in [maxWidth].
  static ({double cellSize, double gap, double totalWidth}) forWidth(
    double maxWidth,
  ) {
    final usable = (maxWidth - horizontalInset).clamp(0.0, maxWidth);
    final raw = (usable - gap * (cellCount - 1)) / cellCount;
    final cellSize = raw.clamp(minCellSize, maxCellSize);
    final totalWidth = cellSize * cellCount + gap * (cellCount - 1);
    return (cellSize: cellSize, gap: gap, totalWidth: totalWidth);
  }
}

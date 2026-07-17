import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/stats_breakdown.dart';

/// Stacked bar chart with legend for Focus / Workout period breakdowns.
class StackedPeriodBarChart extends StatelessWidget {
  final String title;
  final StackedChartData data;
  final String emptyMessage;
  final double chartHeight;

  const StackedPeriodBarChart({
    super.key,
    required this.title,
    required this.data,
    this.emptyMessage = 'No data for this period',
    this.chartHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.buckets.fold<double>(
      0,
      (m, b) => b.total > m ? b.total : m,
    );
    final hasBars = maxY > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppUiSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: AppColorPalette.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            if (!hasBars)
              SizedBox(
                height: chartHeight * 0.5,
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final bucket in data.buckets)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: CustomPaint(
                            painter: _StackedBarPainter(
                              bucket: bucket,
                              series: data.series,
                              maxY: maxY,
                              trackColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppUiSizes.sm),
              Row(
                children: [
                  for (final bucket in data.buckets)
                    Expanded(
                      child: Text(
                        bucket.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                ],
              ),
              if (data.series.isNotEmpty) ...[
                const SizedBox(height: AppUiSizes.md),
                Wrap(
                  spacing: AppUiSizes.md,
                  runSpacing: AppUiSizes.xs,
                  children: [
                    for (final s in data.series)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: AppUiSizes.xs),
                          Text(
                            s.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: AppColorPalette.fontSizeSmall,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  final StackedBarBucket bucket;
  final List<StatsSeriesMeta> series;
  final double maxY;
  final Color trackColor;

  _StackedBarPainter({
    required this.bucket,
    required this.series,
    required this.maxY,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      trackPaint,
    );

    final total = bucket.total;
    if (total <= 0 || maxY <= 0 || size.height <= 0 || size.width <= 0) return;

    final barH = (total / maxY) * size.height;
    var y = size.height;
    // Draw bottom → top so "first" series sits at the base.
    for (final s in series.reversed) {
      final v = bucket.valuesBySeries[s.id] ?? 0;
      if (v <= 0) continue;
      final h = (v / total) * barH;
      y -= h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y, size.width, h),
          const Radius.circular(1),
        ),
        Paint()..color = s.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) {
    return oldDelegate.bucket != bucket ||
        oldDelegate.maxY != maxY ||
        oldDelegate.series != series;
  }
}

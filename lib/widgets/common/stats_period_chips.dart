import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';

/// Shared stats time window for Focus / Workouts / Overview collectibles.
enum StatsPeriod {
  today('Today'),
  week('Week'),
  month('Month'),
  year('Year');

  const StatsPeriod(this.label);
  final String label;

  static const List<StatsPeriod> valuesInUiOrder = [
    StatsPeriod.today,
    StatsPeriod.week,
    StatsPeriod.month,
    StatsPeriod.year,
  ];
}

/// Inclusive-start / exclusive-end window for a [StatsPeriod].
class StatsPeriodRange {
  /// Lower bound (inclusive). Null means unbounded (past).
  final DateTime? start;

  /// Upper bound (exclusive). Null means unbounded (now and future).
  final DateTime? endExclusive;

  const StatsPeriodRange({this.start, this.endExclusive});

  bool contains(DateTime instant) {
    if (start != null && instant.isBefore(start!)) return false;
    if (endExclusive != null && !instant.isBefore(endExclusive!)) return false;
    return true;
  }

  /// Resolve the range for [period] relative to [now] (local time).
  static StatsPeriodRange forPeriod(
    StatsPeriod period, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    switch (period) {
      case StatsPeriod.today:
        return StatsPeriodRange(
          start: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case StatsPeriod.week:
        // Rolling week: today + past 6 days.
        return StatsPeriodRange(start: today.subtract(const Duration(days: 6)));
      case StatsPeriod.month:
        return StatsPeriodRange(start: DateTime(n.year, n.month, 1));
      case StatsPeriod.year:
        return StatsPeriodRange(start: DateTime(n.year, 1, 1));
    }
  }

  /// The immediately preceding window of the same shape as [forPeriod].
  /// Today ↔ yesterday, rolling week ↔ prior 7 days, etc.
  static StatsPeriodRange previousPeriod(
    StatsPeriod period, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    switch (period) {
      case StatsPeriod.today:
        return StatsPeriodRange(
          start: today.subtract(const Duration(days: 1)),
          endExclusive: today,
        );
      case StatsPeriod.week:
        final currentStart = today.subtract(const Duration(days: 6));
        return StatsPeriodRange(
          start: currentStart.subtract(const Duration(days: 7)),
          endExclusive: currentStart,
        );
      case StatsPeriod.month:
        final thisMonth = DateTime(n.year, n.month, 1);
        return StatsPeriodRange(
          start: DateTime(n.year, n.month - 1, 1),
          endExclusive: thisMonth,
        );
      case StatsPeriod.year:
        return StatsPeriodRange(
          start: DateTime(n.year - 1, 1, 1),
          endExclusive: DateTime(n.year, 1, 1),
        );
    }
  }

  /// Length of the current period in whole days (for averages). At least 1.
  static int dayCount(StatsPeriod period, {DateTime? now}) {
    return dayCountOf(forPeriod(period, now: now), now: now);
  }

  /// Length of the previous period in whole days. At least 1.
  static int previousDayCount(StatsPeriod period, {DateTime? now}) {
    return dayCountOf(previousPeriod(period, now: now), now: now);
  }

  static int dayCountOf(StatsPeriodRange range, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final start = range.start ?? today;
    final end = range.endExclusive ?? today.add(const Duration(days: 1));
    final days = end.difference(start).inDays;
    return days < 1 ? 1 : days;
  }

  /// Short phrase for empty-state copy ("today", "this week", …).
  static String emptyLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.today:
        return 'today';
      case StatsPeriod.week:
        return 'this week';
      case StatsPeriod.month:
        return 'this month';
      case StatsPeriod.year:
        return 'this year';
    }
  }
}

/// Compact Today / Week / Month / Year chip row used across analytics.
class StatsPeriodChips extends StatelessWidget {
  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;
  final SettingsRectChipSize size;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;

  const StatsPeriodChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = SettingsRectChipSize.compact,
    this.spacing = AppUiSizes.sm,
    this.runSpacing = AppUiSizes.xs,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final chips = SettingsRectChipGroup<StatsPeriod>(
      size: size,
      spacing: spacing,
      runSpacing: runSpacing,
      value: value,
      onChanged: onChanged,
      options: [
        for (final period in StatsPeriod.valuesInUiOrder)
          SettingsRectChipOption(value: period, label: period.label),
      ],
    );
    if (padding == null) return chips;
    return Padding(padding: padding!, child: chips);
  }
}

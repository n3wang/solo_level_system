import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';

/// Shared stats time window for Focus / Workouts / Overview collectibles.
enum StatsPeriod {
  today('Today'),
  week('Week'),
  lastWeek('Last Week'),
  month('Month'),
  lastMonth('Last Month'),
  year('Year'),
  all('All');

  const StatsPeriod(this.label);
  final String label;

  static const List<StatsPeriod> valuesInUiOrder = [
    StatsPeriod.today,
    StatsPeriod.week,
    StatsPeriod.lastWeek,
    StatsPeriod.month,
    StatsPeriod.lastMonth,
    StatsPeriod.year,
    StatsPeriod.all,
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
      case StatsPeriod.lastWeek:
        // Previous calendar week (Mon–Sun) relative to this week's Monday.
        final thisMonday = today.subtract(Duration(days: today.weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        return StatsPeriodRange(start: lastMonday, endExclusive: thisMonday);
      case StatsPeriod.month:
        return StatsPeriodRange(start: DateTime(n.year, n.month, 1));
      case StatsPeriod.lastMonth:
        final thisMonth = DateTime(n.year, n.month, 1);
        final lastMonth = DateTime(n.year, n.month - 1, 1);
        return StatsPeriodRange(start: lastMonth, endExclusive: thisMonth);
      case StatsPeriod.year:
        return StatsPeriodRange(start: DateTime(n.year, 1, 1));
      case StatsPeriod.all:
        return const StatsPeriodRange();
    }
  }

  /// Short phrase for empty-state copy ("today", "this week", …).
  static String emptyLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.today:
        return 'today';
      case StatsPeriod.week:
        return 'this week';
      case StatsPeriod.lastWeek:
        return 'last week';
      case StatsPeriod.month:
        return 'this month';
      case StatsPeriod.lastMonth:
        return 'last month';
      case StatsPeriod.year:
        return 'this year';
      case StatsPeriod.all:
        return 'yet';
    }
  }
}

/// Compact Today / Week / Last Week / … chip row used across analytics.
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

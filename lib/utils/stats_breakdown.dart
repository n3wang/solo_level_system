import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/widgets/common/stats_period_chips.dart';

/// Stable series ids for stacked analytics charts.
class StatsSeriesId {
  static const String misc = '__misc__';
  static const String def = '__default__';
}

class StatsSeriesMeta {
  final String id;
  final String label;
  final Color color;

  const StatsSeriesMeta({
    required this.id,
    required this.label,
    required this.color,
  });
}

class StackedBarBucket {
  final String label;
  final DateTime start;
  final Map<String, double> valuesBySeries;

  const StackedBarBucket({
    required this.label,
    required this.start,
    required this.valuesBySeries,
  });

  double get total =>
      valuesBySeries.values.fold<double>(0, (a, b) => a + b);
}

class StackedChartData {
  final List<StatsSeriesMeta> series;
  final List<StackedBarBucket> buckets;

  const StackedChartData({required this.series, required this.buckets});

  Map<String, Color> get colorById => {
        for (final s in series) s.id: s.color,
      };
}

class StreakStats {
  final int current;
  final int maxAllTime;
  final int maxThisYear;
  final String unitLabel;

  const StreakStats({
    required this.current,
    required this.maxAllTime,
    required this.maxThisYear,
    required this.unitLabel,
  });
}

enum _StreakGrain { day, week, month }

_StreakGrain _grainForPeriod(StatsPeriod period) {
  switch (period) {
    case StatsPeriod.today:
    case StatsPeriod.week:
      return _StreakGrain.day;
    case StatsPeriod.month:
      return _StreakGrain.week;
    case StatsPeriod.year:
      return _StreakGrain.month;
  }
}

String _unitLabel(_StreakGrain grain) {
  switch (grain) {
    case _StreakGrain.day:
      return 'days';
    case _StreakGrain.week:
      return 'weeks';
    case _StreakGrain.month:
      return 'months';
  }
}

DateTime _local(DateTime d) => d.toLocal();

DateTime _dateOnly(DateTime d) {
  final l = _local(d);
  return DateTime(l.year, l.month, l.day);
}

DateTime _weekStart(DateTime d) {
  final day = _dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime _monthStart(DateTime d) {
  final l = _local(d);
  return DateTime(l.year, l.month, 1);
}

DateTime _bucketKey(DateTime instant, _StreakGrain grain) {
  switch (grain) {
    case _StreakGrain.day:
      return _dateOnly(instant);
    case _StreakGrain.week:
      return _weekStart(instant);
    case _StreakGrain.month:
      return _monthStart(instant);
  }
}

DateTime _prevBucket(DateTime key, _StreakGrain grain) {
  switch (grain) {
    case _StreakGrain.day:
      return key.subtract(const Duration(days: 1));
    case _StreakGrain.week:
      return key.subtract(const Duration(days: 7));
    case _StreakGrain.month:
      return DateTime(key.year, key.month - 1, 1);
  }
}

/// Top [maxNamed] named groups (palette colors 1–5) + misc + default.
List<StatsSeriesMeta> buildTopSeries({
  required Map<String, double> totalsById,
  required Map<String, String> labelsById,
  required String Function(String id) defaultLabel,
  int maxNamed = 5,
}) {
  final named = totalsById.entries
      .where((e) => e.key != StatsSeriesId.def && e.value > 0)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final top = named.take(maxNamed).toList();
  final topIds = top.map((e) => e.key).toSet();
  final hasMisc = named.any((e) => !topIds.contains(e.key));
  final hasDefault = (totalsById[StatsSeriesId.def] ?? 0) > 0;

  final series = <StatsSeriesMeta>[
    for (var i = 0; i < top.length; i++)
      StatsSeriesMeta(
        id: top[i].key,
        label: labelsById[top[i].key] ?? defaultLabel(top[i].key),
        color: AppColorPalette.getColorByIndex(i),
      ),
    if (hasMisc)
      StatsSeriesMeta(
        id: StatsSeriesId.misc,
        label: 'Misc',
        color: AppColorPalette.grey500,
      ),
    if (hasDefault)
      StatsSeriesMeta(
        id: StatsSeriesId.def,
        label: 'Default',
        color: AppColorPalette.grey400,
      ),
  ];
  return series;
}

String resolveSeriesId({
  required String? groupId,
  required Set<String> topIds,
}) {
  if (groupId == null || groupId.isEmpty) return StatsSeriesId.def;
  if (topIds.contains(groupId)) return groupId;
  return StatsSeriesId.misc;
}

StackedChartData buildStackedChart({
  required StatsPeriod period,
  required DateTime now,
  required Iterable<DateTime> timestamps,
  required String? Function(int index) groupIdAt,
  required String? Function(int index) groupLabelAt,
  required double Function(int index) valueAt,
  int maxNamed = 5,
}) {
  final list = timestamps.map(_local).toList();
  final totals = <String, double>{};
  final labels = <String, String>{};

  for (var i = 0; i < list.length; i++) {
    final gid = groupIdAt(i);
    final key = (gid == null || gid.isEmpty) ? StatsSeriesId.def : gid;
    totals[key] = (totals[key] ?? 0) + valueAt(i);
    if (key != StatsSeriesId.def) {
      labels[key] = groupLabelAt(i) ?? key;
    }
  }

  final series = buildTopSeries(
    totalsById: totals,
    labelsById: labels,
    defaultLabel: (id) => id,
    maxNamed: maxNamed,
  );
  final topIds = series
      .map((s) => s.id)
      .where((id) => id != StatsSeriesId.misc && id != StatsSeriesId.def)
      .toSet();

  final buckets = _chartBuckets(period, _local(now));
  final values = [
    for (final _ in buckets)
      <String, double>{for (final s in series) s.id: 0.0},
  ];

  for (var i = 0; i < list.length; i++) {
    final bi = _bucketIndex(list[i], buckets);
    if (bi == null) continue;
    final sid = resolveSeriesId(groupId: groupIdAt(i), topIds: topIds);
    if (!values[bi].containsKey(sid)) continue;
    values[bi][sid] = values[bi][sid]! + valueAt(i);
  }

  return StackedChartData(
    series: series,
    buckets: [
      for (var i = 0; i < buckets.length; i++)
        StackedBarBucket(
          label: buckets[i].label,
          start: buckets[i].start,
          valuesBySeries: values[i],
        ),
    ],
  );
}

class _ChartBucketDef {
  final String label;
  final DateTime start;
  final DateTime endExclusive;

  const _ChartBucketDef({
    required this.label,
    required this.start,
    required this.endExclusive,
  });
}

List<_ChartBucketDef> _chartBuckets(StatsPeriod period, DateTime now) {
  final today = _dateOnly(now);
  switch (period) {
    case StatsPeriod.today:
      return [
        for (var h = 0; h < 24; h++)
          _ChartBucketDef(
            label: h % 6 == 0 ? '${h}h' : '',
            start: DateTime(today.year, today.month, today.day, h),
            endExclusive: DateTime(today.year, today.month, today.day, h + 1),
          ),
      ];
    case StatsPeriod.week:
      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return [
        for (var i = 6; i >= 0; i--)
          () {
            final d = today.subtract(Duration(days: i));
            return _ChartBucketDef(
              label: names[d.weekday - 1],
              start: d,
              endExclusive: d.add(const Duration(days: 1)),
            );
          }(),
      ];
    case StatsPeriod.month:
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final buckets = <_ChartBucketDef>[];
      var cursor = _weekStart(monthStart);
      var weekNum = 1;
      while (cursor.isBefore(nextMonth)) {
        final end = cursor.add(const Duration(days: 7));
        buckets.add(
          _ChartBucketDef(
            label: 'W$weekNum',
            start: cursor,
            endExclusive: end,
          ),
        );
        cursor = end;
        weekNum++;
      }
      return buckets;
    case StatsPeriod.year:
      const names = [
        'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
      ];
      return [
        for (var m = 1; m <= 12; m++)
          _ChartBucketDef(
            label: names[m - 1],
            start: DateTime(now.year, m, 1),
            endExclusive: DateTime(now.year, m + 1, 1),
          ),
      ];
  }
}

int? _bucketIndex(DateTime t, List<_ChartBucketDef> buckets) {
  final local = _local(t);
  for (var i = 0; i < buckets.length; i++) {
    final b = buckets[i];
    if (!local.isBefore(b.start) && local.isBefore(b.endExclusive)) return i;
  }
  // Fallback: match by calendar day when timezones shift the instant.
  final day = _dateOnly(local);
  for (var i = 0; i < buckets.length; i++) {
    final b = buckets[i];
    final spanDays = b.endExclusive.difference(b.start).inDays;
    if (spanDays == 1 && _dateOnly(b.start) == day) return i;
  }
  return null;
}

StreakStats computeStreakStats({
  required StatsPeriod period,
  required Iterable<DateTime> activityTimes,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final grain = _grainForPeriod(period);
  final active = <DateTime>{
    for (final t in activityTimes) _bucketKey(t, grain),
  };

  int longestIn(Iterable<DateTime> keys) {
    final sorted = keys.toList()..sort();
    if (sorted.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (_prevBucket(sorted[i], grain) == sorted[i - 1]) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  final yearStart = DateTime(n.year, 1, 1);
  final inYear = active.where((k) => !k.isBefore(yearStart));

  var currentKey = _bucketKey(n, grain);
  if (!active.contains(currentKey)) {
    currentKey = _prevBucket(currentKey, grain);
  }
  var current = 0;
  var cursor = currentKey;
  while (active.contains(cursor)) {
    current++;
    cursor = _prevBucket(cursor, grain);
  }

  return StreakStats(
    current: current,
    maxAllTime: longestIn(active),
    maxThisYear: longestIn(inYear),
    unitLabel: _unitLabel(grain),
  );
}

/// Set-type id stored on workout sessions (preferred), else [routineId].
String? workoutSetGroupId(Map<String, dynamic> additionalData, String routineId) {
  final fromMeta = additionalData['setCategoryId'];
  if (fromMeta is String && fromMeta.isNotEmpty) return fromMeta;
  if (routineId.isNotEmpty) return routineId;
  return null;
}

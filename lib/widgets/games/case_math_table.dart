import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Renders one Case Math table view (company×years, products×metrics, or costs).
class CaseMathTable extends StatelessWidget {
  const CaseMathTable({
    super.key,
    required this.view,
    this.entityIndex = 0,
    this.highlights = const [],
    this.onCellTap,
  });

  final CaseMathTableView view;
  final int entityIndex;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  @override
  Widget build(BuildContext context) {
    return switch (view.definition.kind) {
      CaseMathTableKind.companyYears => _MetricTimeBlock(
          view: view,
          entity: view.entities[entityIndex.clamp(0, view.entities.length - 1)],
          highlights: highlights,
          onCellTap: onCellTap,
        ),
      CaseMathTableKind.entityMetric => _EntityMetricBlock(
          view: view,
          highlights: highlights,
          onCellTap: onCellTap,
        ),
      CaseMathTableKind.fixedCosts => _FixedCostBlock(
          view: view,
          highlights: highlights,
          onCellTap: onCellTap,
        ),
    };
  }
}

Color? _highlightColor(
  List<CaseMathFormulaHighlight> highlights, {
  required String tableId,
  required String entityId,
  required String valueId,
  int yearIndex = 0,
}) {
  for (final highlight in highlights) {
    if ((highlight.tableId ?? tableId) == tableId &&
        (highlight.entityId ?? entityId) == entityId &&
        highlight.valueId == valueId &&
        highlight.yearIndex == yearIndex) {
      return _paletteColor(highlight.colorIndex).withValues(alpha: 0.28);
    }
  }
  return null;
}

Color? _labelColor(
  List<CaseMathFormulaHighlight> highlights, {
  required String tableId,
  required String matchId,
  bool matchEntity = false,
}) {
  for (final highlight in highlights) {
    final hit = matchEntity
        ? (highlight.entityId ?? '') == matchId
        : highlight.valueId == matchId;
    if ((highlight.tableId ?? tableId) == tableId && hit) {
      return _paletteColor(highlight.colorIndex);
    }
  }
  return null;
}

Color _paletteColor(int index) {
  return switch (index % 5) {
    0 => AppColorPalette.color1,
    1 => AppColorPalette.color2,
    2 => AppColorPalette.color3,
    3 => AppColorPalette.color4,
    _ => AppColorPalette.color5,
  };
}

class _MetricTimeBlock extends StatelessWidget {
  const _MetricTimeBlock({
    required this.view,
    required this.entity,
    required this.highlights,
    this.onCellTap,
  });

  final CaseMathTableView view;
  final CaseMathEntityData entity;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  @override
  Widget build(BuildContext context) {
    final yearCount = view.yearLabels.length;
    final columnWidths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(1.45),
      for (var i = 0; i < yearCount; i++) i + 1: const FlexColumnWidth(1),
    };
    final tableId = view.definition.id;

    return _TableShell(
      title: entity.name,
      columnWidths: columnWidths,
      header: [
        _HeaderCell('Metric', align: TextAlign.left),
        for (final year in view.yearLabels)
          _HeaderCell(year, align: TextAlign.right),
      ],
      rows: [
        for (final metric in view.displayMetrics)
          [
            _MetricCell(
              label: metric.name,
              color: _labelColor(
                highlights,
                tableId: tableId,
                matchId: metric.id,
              ),
            ),
            for (var i = 0; i < yearCount; i++)
              _ValueCell(
                text: CaseMathScoring.formatValue(
                  entity.at(metric.id, i),
                  metric.format,
                ),
                highlight: _highlightColor(
                  highlights,
                  tableId: tableId,
                  entityId: entity.id,
                  valueId: metric.id,
                  yearIndex: i,
                ),
                onTap: onCellTap == null
                    ? null
                    : () => onCellTap!(entity.at(metric.id, i)),
              ),
          ],
      ],
    );
  }
}

class _EntityMetricBlock extends StatelessWidget {
  const _EntityMetricBlock({
    required this.view,
    required this.highlights,
    this.onCellTap,
  });

  final CaseMathTableView view;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  @override
  Widget build(BuildContext context) {
    final metrics = view.displayMetrics;
    final columnWidths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(1.55),
      for (var i = 0; i < metrics.length; i++) i + 1: const FlexColumnWidth(1),
    };
    final tableId = view.definition.id;

    return _TableShell(
      title: view.definition.title,
      columnWidths: columnWidths,
      header: [
        _HeaderCell('Product', align: TextAlign.left),
        for (final metric in metrics)
          _HeaderCell(metric.name, align: TextAlign.right),
      ],
      rows: [
        for (final entity in view.entities)
          [
            _MetricCell(
              label: entity.name,
              color: _labelColor(
                highlights,
                tableId: tableId,
                matchId: entity.id,
                matchEntity: true,
              ),
            ),
            for (final metric in metrics)
              _ValueCell(
                text: CaseMathScoring.formatValue(
                  entity.at(metric.id),
                  metric.format,
                ),
                highlight: _highlightColor(
                  highlights,
                  tableId: tableId,
                  entityId: entity.id,
                  valueId: metric.id,
                ),
                onTap: onCellTap == null
                    ? null
                    : () => onCellTap!(entity.at(metric.id)),
              ),
          ],
      ],
    );
  }
}

class _FixedCostBlock extends StatelessWidget {
  const _FixedCostBlock({
    required this.view,
    required this.highlights,
    this.onCellTap,
  });

  final CaseMathTableView view;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  @override
  Widget build(BuildContext context) {
    final tableId = view.definition.id;
    return _TableShell(
      title: view.definition.title,
      columnWidths: const {
        0: FlexColumnWidth(1.8),
        1: FlexColumnWidth(1),
      },
      header: [
        _HeaderCell('Cost', align: TextAlign.left),
        _HeaderCell('Amount', align: TextAlign.right),
      ],
      rows: [
        for (final entity in view.entities)
          [
            _MetricCell(
              label: entity.name,
              color: _labelColor(
                highlights,
                tableId: tableId,
                matchId: entity.id,
                matchEntity: true,
              ),
            ),
            _ValueCell(
              text: CaseMathScoring.formatValue(
                entity.at('amount'),
                CaseMathValueFormat.price,
              ),
              highlight: _highlightColor(
                highlights,
                tableId: tableId,
                entityId: entity.id,
                valueId: 'amount',
              ),
              onTap: onCellTap == null
                  ? null
                  : () => onCellTap!(entity.at('amount')),
            ),
          ],
      ],
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({
    required this.title,
    required this.columnWidths,
    required this.header,
    required this.rows,
  });

  final String title;
  final Map<int, TableColumnWidth> columnWidths;
  final List<Widget> header;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.55),
          width: AppUiSizes.smallBorderWidth,
        ),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.black.withValues(alpha: 0.04),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Table(
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 0.6,
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.02),
                ),
                children: header,
              ),
              for (final row in rows) TableRow(children: row),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.align});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColorPalette.textSecondary,
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 5, 2, 5),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.15,
          color: color,
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.text, this.highlight, this.onTap});

  final String text;
  final Color? highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = ColoredBox(
      color: highlight ?? Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            fontSize: 10,
            fontFeatures: [FontFeature.tabularFigures()],
            height: 1.15,
          ),
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

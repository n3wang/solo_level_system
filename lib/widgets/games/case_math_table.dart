import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Minimal Case Math comparison table (2 companies × 4 years).
/// Sized to fit all year columns without horizontal scrolling.
class CaseMathTable extends StatelessWidget {
  const CaseMathTable({
    super.key,
    required this.table,
    this.companyIndex = 0,
    this.highlights = const [],
    this.onCellTap,
  });

  final CaseMathRoundTable table;
  final int companyIndex;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompanyBlock(
          table: table,
          company: table.companies[companyIndex],
          highlights: highlights,
          onCellTap: onCellTap,
        ),
      ],
    );
  }
}

class _CompanyBlock extends StatelessWidget {
  const _CompanyBlock({
    required this.table,
    required this.company,
    required this.highlights,
    this.onCellTap,
  });

  final CaseMathRoundTable table;
  final CaseMathCompanyData company;
  final List<CaseMathFormulaHighlight> highlights;
  final void Function(double value)? onCellTap;

  Color? _cellColor(String valueId, int yearIndex) {
    for (final highlight in highlights) {
      if (highlight.valueId == valueId && highlight.yearIndex == yearIndex) {
        return _paletteColor(highlight.colorIndex).withValues(alpha: 0.28);
      }
    }
    return null;
  }

  Color? _rowLabelColor(String valueId) {
    for (final highlight in highlights) {
      if (highlight.valueId == valueId) {
        return _paletteColor(highlight.colorIndex);
      }
    }
    return null;
  }

  static Color _paletteColor(int index) {
    return switch (index % 5) {
      0 => AppColorPalette.color1,
      1 => AppColorPalette.color2,
      2 => AppColorPalette.color3,
      3 => AppColorPalette.color4,
      _ => AppColorPalette.color5,
    };
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = table.yearLabels.length;
    final columnWidths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(1.45),
      for (var i = 0; i < yearCount; i++) i + 1: const FlexColumnWidth(1),
    };

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
              company.name,
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
                children: [
                  _HeaderCell('Metric', align: TextAlign.left),
                  for (final year in table.yearLabels)
                    _HeaderCell(year, align: TextAlign.right),
                ],
              ),
              for (final valueDefinition in table.displayValues)
                TableRow(
                  children: [
                    _MetricCell(
                      label: valueDefinition.name,
                      color: _rowLabelColor(valueDefinition.id),
                    ),
                    for (var i = 0; i < yearCount; i++)
                      _ValueCell(
                        text: CaseMathScoring.formatValue(
                          company.at(valueDefinition.id, i),
                          valueDefinition.format,
                        ),
                        highlight: _cellColor(valueDefinition.id, i),
                        onTap: onCellTap == null
                            ? null
                            : () =>
                                  onCellTap!(company.at(valueDefinition.id, i)),
                      ),
                  ],
                ),
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
        maxLines: 1,
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

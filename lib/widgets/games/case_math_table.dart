import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Minimal scrollable Case Math comparison table (2 companies × 4 years).
class CaseMathTable extends StatelessWidget {
  const CaseMathTable({super.key, required this.table});

  final CaseMathRoundTable table;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final company in table.companies) ...[
          _CompanyBlock(table: table, company: company),
          const SizedBox(height: AppUiSizes.lg),
        ],
      ],
    );
  }
}

class _CompanyBlock extends StatelessWidget {
  const _CompanyBlock({required this.table, required this.company});

  final CaseMathRoundTable table;
  final CaseMathCompanyData company;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: Colors.black.withValues(alpha: 0.55),
      width: AppUiSizes.smallBorderWidth,
    );

    return Container(
      decoration: BoxDecoration(
        border: border,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.black.withValues(alpha: 0.04),
            child: Text(
              '${company.name} (${company.id})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 36,
              columnSpacing: 14,
              horizontalMargin: 10,
              headingTextStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColorPalette.textSecondary,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 11,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              columns: [
                const DataColumn(label: Text('Metric')),
                for (final y in table.yearLabels)
                  DataColumn(
                    label: Text(y),
                    numeric: true,
                  ),
              ],
              rows: [
                for (final valueDefinition in table.definition.values)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 128,
                          child: Text(
                            valueDefinition.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: valueDefinition.isDistractor
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: valueDefinition.isDistractor
                                  ? AppColorPalette.textSecondary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < table.yearLabels.length; i++)
                        DataCell(
                          Text(
                            CaseMathScoring.formatValue(
                              company.at(valueDefinition.id, i),
                              valueDefinition.format,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

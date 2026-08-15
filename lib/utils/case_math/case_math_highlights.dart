import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Builds colored formula references for table + solution highlighting.
class CaseMathHighlightBuilder {
  CaseMathHighlightBuilder._();

  static const paletteSize = 5;

  static List<CaseMathFormulaHighlight> build({
    required CaseMathRoundTable table,
    required CaseMathQuestion question,
  }) {
    final highlights = <CaseMathFormulaHighlight>[];
    final seen = <String>{};
    var colorIndex = 0;

    final orderedNames = _variableOrder(
      question.definition.math,
      question.variables.keys,
    );

    for (final name in orderedNames) {
      final binding = question.definition.variables[name]!;
      final valueId = binding.valueId;
      if (valueId == null) continue;

      final tableId = binding.tableId ??
          question.focusTableId ??
          table.views.first.definition.id;
      final view = table.view(tableId);
      final yearIndex = question.yearIndex + binding.yearOffset;

      String entityId;
      String metricId;
      String metricName;
      if (view.definition.kind == CaseMathTableKind.fixedCosts) {
        entityId = binding.entityRef ?? valueId;
        metricId = 'amount';
        metricName = view.entity(entityId).name;
      } else {
        entityId = _resolveEntityId(
          table: table,
          view: view,
          binding: binding,
          focusEntityId: question.companyId,
        );
        metricId = valueId;
        metricName = view.definition.metrics
            .firstWhere((metric) => metric.id == valueId)
            .name;
      }

      final key = '$tableId|$entityId|$metricId@$yearIndex';
      if (!seen.add(key)) continue;

      highlights.add(
        CaseMathFormulaHighlight(
          variableName: name,
          valueId: metricId,
          yearIndex: yearIndex,
          metricName: metricName,
          formattedValue: CaseMathScoring.formatValue(
            question.variables[name]!,
            question.variableFormats[name]!,
          ),
          colorIndex: colorIndex % paletteSize,
          tableId: tableId,
          entityId: entityId,
        ),
      );
      colorIndex++;
    }
    return highlights;
  }

  static String _resolveEntityId({
    required CaseMathRoundTable table,
    required CaseMathTableView view,
    required CaseMathVariableBinding binding,
    required String focusEntityId,
  }) {
    final ref = binding.entityRef;
    if (ref == null || ref == 'focus') return focusEntityId;
    if (ref.startsWith('shared')) {
      final index = int.tryParse(ref.replaceFirst('shared', '')) ?? 0;
      return table.sharedProductIds[index];
    }
    if (ref.startsWith('slot')) {
      final index = int.tryParse(ref.replaceFirst('slot', '')) ?? 0;
      return view.entities[index].id;
    }
    if (ref.startsWith('entity:')) {
      return ref.substring('entity:'.length);
    }
    return ref;
  }

  static List<CaseMathSolutionPart> buildSolutionParts({
    required CaseMathQuestion question,
    required double exact,
    required List<CaseMathFormulaHighlight> highlights,
  }) {
    final byVariable = {
      for (final highlight in highlights) highlight.variableName: highlight,
    };
    final parts = <CaseMathSolutionPart>[];
    final source = question.definition.math;
    final pattern = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|[0-9]*\.?[0-9]+|.');
    for (final match in pattern.allMatches(source)) {
      final token = match.group(0)!;
      final highlight = byVariable[token];
      if (highlight != null) {
        parts.add(
          CaseMathSolutionPart(
            text: highlight.formattedValue,
            highlight: highlight,
          ),
        );
      } else if (question.variables.containsKey(token)) {
        parts.add(
          CaseMathSolutionPart(
            text: CaseMathScoring.formatValue(
              question.variables[token]!,
              question.variableFormats[token]!,
            ),
          ),
        );
      } else {
        parts.add(CaseMathSolutionPart(text: token));
      }
    }
    parts.add(const CaseMathSolutionPart(text: ' = '));
    parts.add(
      CaseMathSolutionPart(
        text: CaseMathScoring.formatValue(
          exact,
          question.definition.answerType,
        ),
      ),
    );
    return parts;
  }

  static List<String> _variableOrder(String math, Iterable<String> names) {
    final remaining = names.toSet();
    final ordered = <String>[];
    final pattern = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
    for (final match in pattern.allMatches(math)) {
      final name = match.group(0)!;
      if (remaining.remove(name)) ordered.add(name);
    }
    for (final name in names) {
      if (remaining.contains(name)) ordered.add(name);
    }
    return ordered;
  }
}

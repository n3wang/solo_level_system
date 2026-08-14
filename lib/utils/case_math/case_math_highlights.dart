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

    // Prefer variable order as they appear in the math expression.
    final orderedNames = _variableOrder(
      question.definition.math,
      question.variables.keys,
    );

    for (final name in orderedNames) {
      final binding = question.definition.variables[name]!;
      final valueId = binding.valueId;
      if (valueId == null) continue;

      final yearIndex = question.yearIndex + binding.yearOffset;
      final key = '$valueId@$yearIndex';
      if (!seen.add(key)) continue;

      final metric = table.definition.value(valueId);
      highlights.add(
        CaseMathFormulaHighlight(
          variableName: name,
          valueId: valueId,
          yearIndex: yearIndex,
          metricName: metric.name,
          formattedValue: CaseMathScoring.formatValue(
            question.variables[name]!,
            question.variableFormats[name]!,
          ),
          colorIndex: colorIndex % paletteSize,
        ),
      );
      colorIndex++;
    }
    return highlights;
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

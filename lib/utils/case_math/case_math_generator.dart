import 'dart:math';

import 'package:solo_level_system/utils/case_math/case_math_expression.dart';
import 'package:solo_level_system/utils/case_math/case_math_highlights.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Generates any case from its value and question definitions.
class CaseMathGenerator {
  CaseMathGenerator({
    required this.definition,
    Random? random,
  }) : _random = random ?? Random() {
    _validateDefinition();
    reshuffleDisplayOrder();
  }

  final CaseMathCaseDefinition definition;
  final Random _random;
  late List<CaseMathValueDefinition> _displayValues;

  /// Call once when a game session starts (not between questions).
  void reshuffleDisplayOrder() {
    _displayValues = [...definition.values]..shuffle(_random);
  }

  CaseMathRound nextRound() {
    final startYear = 2019 + _random.nextInt(5);
    final years =
        List.generate(definition.yearCount, (index) => '${startYear + index}');
    final names = [...definition.companyNames]..shuffle(_random);
    final companies = List.generate(
      2,
      (index) => _generateCompany(
        id: String.fromCharCode(65 + index),
        name: names[index],
      ),
    );
    final table = CaseMathRoundTable(
      definition: definition,
      yearLabels: years,
      companies: companies,
      displayValues: List.unmodifiable(_displayValues),
    );
    final question = _buildQuestion(table);
    final exact = CaseMathExpression.evaluate(
      question.definition.math,
      question.variables,
    );
    final highlights = CaseMathHighlightBuilder.build(
      table: table,
      question: question,
    );
    final solutionParts = CaseMathHighlightBuilder.buildSolutionParts(
      question: question,
      exact: exact,
      highlights: highlights,
    );
    final answer = CaseMathWorkedAnswer(
      exact: exact,
      formula: question.definition.formula,
      solution: CaseMathScoring.buildSolution(question, exact),
      type: question.definition.answerType,
      highlights: highlights,
      solutionParts: solutionParts,
    );
    return CaseMathRound(table: table, question: question, answer: answer);
  }

  CaseMathCompanyData _generateCompany({
    required String id,
    required String name,
  }) {
    return CaseMathCompanyData(
      id: id,
      name: name,
      values: {
        for (final value in definition.values)
          value.id: _generateSeries(value),
      },
    );
  }

  List<double> _generateSeries(CaseMathValueDefinition definition) {
    final values = <double>[];
    var current = _randomIn(definition.range);
    for (var year = 0; year < this.definition.yearCount; year++) {
      if (year > 0) {
        current *= _randomIn(definition.growthRange);
      }
      values.add(_makeUgly(current, definition.decimalPlaces));
    }
    return values;
  }

  CaseMathQuestion _buildQuestion(CaseMathRoundTable table) {
    final definition =
        this.definition.questions[_random.nextInt(this.definition.questions.length)];
    final company =
        table.companies[_random.nextInt(table.companies.length)];
    final availableYears =
        table.yearLabels.length - definition.minimumPreviousYears;
    final yearIndex =
        definition.minimumPreviousYears + _random.nextInt(availableYears);
    final variables = <String, double>{};
    final variableFormats = <String, CaseMathValueFormat>{};

    for (final entry in definition.variables.entries) {
      final binding = entry.value;
      variableFormats[entry.key] =
          binding.format ?? _formatForBinding(binding);
      if (binding.valueId != null) {
        variables[entry.key] = company.at(
          binding.valueId!,
          yearIndex + binding.yearOffset,
        );
      } else {
        variables[entry.key] = _randomParameter(binding.randomRange!);
      }
    }

    var prompt = definition.questionText
        .replaceAll('{company}', company.name)
        .replaceAll('{companyId}', company.id)
        .replaceAll('{year}', table.yearLabels[yearIndex])
        .replaceAll(
          '{previousYear}',
          table.yearLabels[max(0, yearIndex - 1)],
        );
    for (final entry in variables.entries) {
      final binding = definition.variables[entry.key]!;
      final format = binding.format ?? _formatForBinding(binding);
      final text = CaseMathScoring.formatValue(entry.value, format);
      prompt = prompt.replaceAll('{${entry.key}}', text);
    }

    return CaseMathQuestion(
      definition: definition,
      companyId: company.id,
      yearIndex: yearIndex,
      prompt: prompt,
      variables: variables,
      variableFormats: variableFormats,
    );
  }

  CaseMathValueFormat _formatForBinding(CaseMathVariableBinding binding) {
    return definition.value(binding.valueId!).format;
  }

  double _randomParameter(CaseMathRange range) {
    // Question parameters use clean 5-point steps while table values stay ugly.
    final min = range.min.round();
    final max = range.max.round();
    final steps = ((max - min) ~/ 5) + 1;
    return (min + _random.nextInt(steps) * 5).toDouble();
  }

  double _randomIn(CaseMathRange range) =>
      range.min + _random.nextDouble() * (range.max - range.min);

  double _makeUgly(double value, int decimals) {
    if (decimals > 0) {
      final factor = pow(10, decimals).toDouble();
      var result = (value * factor).round() / factor;
      if ((result * factor).round() % 10 == 0) result += 3 / factor;
      return result;
    }
    var result = value.round() + _random.nextInt(181) - 90;
    if (result < 1) result = 1 + _random.nextInt(89);
    if (result % 100 == 0 || result % 500 == 0) {
      result += 17 + _random.nextInt(71);
    }
    return result.toDouble();
  }

  void _validateDefinition() {
    if (definition.companyNames.length < 2) {
      throw ArgumentError('A case needs at least two company names');
    }
    if (definition.values.isEmpty || definition.questions.isEmpty) {
      throw ArgumentError('A case needs values and questions');
    }
    final ids = definition.values.map((value) => value.id).toSet();
    if (ids.length != definition.values.length) {
      throw ArgumentError('Case value IDs must be unique');
    }
    for (final question in definition.questions) {
      if (question.caseId != definition.id) {
        throw ArgumentError('Question ${question.id} has the wrong case ID');
      }
      for (final binding in question.variables.values) {
        if (binding.valueId != null && !ids.contains(binding.valueId)) {
          throw ArgumentError(
            'Question ${question.id} references ${binding.valueId}',
          );
        }
      }
    }
  }
}

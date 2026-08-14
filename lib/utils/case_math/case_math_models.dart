// Generic data model. New cases should be definitions, not new model classes.

enum CaseMathValueFormat { number, price, percentage }

class CaseMathRange {
  const CaseMathRange(this.min, this.max) : assert(max >= min);

  final double min;
  final double max;
}

/// A table row definition.
///
/// Example: `id: revenue`, `range: 20000000–40000000`, `format: price`.
class CaseMathValueDefinition {
  const CaseMathValueDefinition({
    required this.id,
    required this.name,
    required this.caseId,
    required this.range,
    this.format = CaseMathValueFormat.number,
    this.growthRange = const CaseMathRange(0.94, 1.18),
    this.decimalPlaces = 0,
    this.isDistractor = false,
  });

  final String id;
  final String name;
  final String caseId;
  final CaseMathRange range;
  final CaseMathValueFormat format;
  final CaseMathRange growthRange;
  final int decimalPlaces;
  final bool isDistractor;
}

/// Binds a variable used by a question's math expression.
///
/// A binding either reads a table value or randomizes a question parameter.
class CaseMathVariableBinding {
  const CaseMathVariableBinding.value(
    this.valueId, {
    this.yearOffset = 0,
    this.format,
  }) : randomRange = null;

  const CaseMathVariableBinding.random(
    this.randomRange, {
    this.format = CaseMathValueFormat.number,
  })  : valueId = null,
        yearOffset = 0;

  final String? valueId;
  final int yearOffset;
  final CaseMathRange? randomRange;
  final CaseMathValueFormat? format;
}

/// A question is fully declarative: text template + variables + arithmetic.
///
/// Supported text tokens: `{company}`, `{companyId}`, `{year}`,
/// `{previousYear}`, plus any variable name (for example `{upliftPercent}`).
class CaseMathQuestionDefinition {
  const CaseMathQuestionDefinition({
    required this.id,
    required this.caseId,
    required this.questionText,
    required this.math,
    required this.formula,
    required this.variables,
    this.answerType = CaseMathValueFormat.number,
    this.minimumPreviousYears = 0,
  });

  final String id;
  final String caseId;
  final String questionText;

  /// Arithmetic expression using keys from [variables], e.g. `price * units`.
  final String math;
  final String formula;
  final Map<String, CaseMathVariableBinding> variables;
  final CaseMathValueFormat answerType;
  final int minimumPreviousYears;
}

class CaseMathCaseDefinition {
  const CaseMathCaseDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.companyNames,
    required this.values,
    required this.questions,
    this.yearCount = 4,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> companyNames;
  final List<CaseMathValueDefinition> values;
  final List<CaseMathQuestionDefinition> questions;
  final int yearCount;

  CaseMathValueDefinition value(String id) =>
      values.firstWhere((value) => value.id == id);
}

class CaseMathCompanyData {
  const CaseMathCompanyData({
    required this.id,
    required this.name,
    required this.values,
  });

  final String id;
  final String name;
  final Map<String, List<double>> values;

  List<double> series(String valueId) => values[valueId]!;
  double at(String valueId, int yearIndex) => values[valueId]![yearIndex];
}

class CaseMathRoundTable {
  const CaseMathRoundTable({
    required this.definition,
    required this.yearLabels,
    required this.companies,
    required this.displayValues,
  });

  final CaseMathCaseDefinition definition;
  final List<String> yearLabels;
  final List<CaseMathCompanyData> companies;

  /// Session-stable row order (shuffled once per game, not per question).
  final List<CaseMathValueDefinition> displayValues;

  CaseMathCompanyData company(String id) =>
      companies.firstWhere((company) => company.id == id);
}

class CaseMathQuestion {
  const CaseMathQuestion({
    required this.definition,
    required this.companyId,
    required this.yearIndex,
    required this.prompt,
    required this.variables,
    required this.variableFormats,
  });

  final CaseMathQuestionDefinition definition;
  final String companyId;
  final int yearIndex;
  final String prompt;
  final Map<String, double> variables;
  final Map<String, CaseMathValueFormat> variableFormats;
}

class CaseMathWorkedAnswer {
  const CaseMathWorkedAnswer({
    required this.exact,
    required this.formula,
    required this.solution,
    required this.type,
    this.variableUsageCount = 1,
    this.highlights = const [],
    this.solutionParts = const [],
  });

  final double exact;
  final String formula;
  final String solution;
  final CaseMathValueFormat type;

  /// How many times formula variables appear in the math expression.
  /// Drives relative scoring tolerance (2.5% accept / 1% precise per use).
  final int variableUsageCount;

  /// Table cells used by the formula (colored in solution + table).
  final List<CaseMathFormulaHighlight> highlights;

  /// Structured solution for colored / tappable spans.
  final List<CaseMathSolutionPart> solutionParts;
}

/// A table-backed value referenced by the active formula.
class CaseMathFormulaHighlight {
  const CaseMathFormulaHighlight({
    required this.variableName,
    required this.valueId,
    required this.yearIndex,
    required this.metricName,
    required this.formattedValue,
    required this.colorIndex,
  });

  final String variableName;
  final String valueId;
  final int yearIndex;
  final String metricName;
  final String formattedValue;

  /// Index into the app primary palette (0 → color1 …).
  final int colorIndex;
}

class CaseMathSolutionPart {
  const CaseMathSolutionPart({
    required this.text,
    this.highlight,
  });

  final String text;
  final CaseMathFormulaHighlight? highlight;
}

class CaseMathRound {
  const CaseMathRound({
    required this.table,
    required this.question,
    required this.answer,
  });

  final CaseMathRoundTable table;
  final CaseMathQuestion question;
  final CaseMathWorkedAnswer answer;
}

class CaseMathScoreResult {
  const CaseMathScoreResult({
    required this.correct,
    required this.guess,
    required this.exact,
    required this.relativeError,
    required this.points,
  });

  final bool correct;
  final double guess;
  final double exact;
  final double relativeError;
  final int points;
}

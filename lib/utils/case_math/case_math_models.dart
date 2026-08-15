// Generic data model. New cases should be definitions, not new model classes.

enum CaseMathValueFormat { number, price, percentage }

/// How a table is laid out on screen.
enum CaseMathTableKind {
  /// Rows = metrics, columns = years, switchable entities (Case 1 companies).
  companyYears,

  /// Rows = named entities (products), columns = metrics (Case 2 products).
  entityMetric,

  /// Rows = cost line items, single amount column (Case 2 fixed costs).
  fixedCosts,
}

class CaseMathRange {
  const CaseMathRange(this.min, this.max) : assert(max >= min);

  final double min;
  final double max;
}

/// A metric / column / cost-line definition inside a table.
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

    /// When true on a fixed-cost row, allocate this cost across [sharedProductIds].
    this.sharedAcrossProducts = false,
  });

  final String id;
  final String name;
  final String caseId;
  final CaseMathRange range;
  final CaseMathValueFormat format;
  final CaseMathRange growthRange;
  final int decimalPlaces;
  final bool isDistractor;
  final bool sharedAcrossProducts;
}

/// One renderable / generatable table inside a case.
class CaseMathTableDefinition {
  const CaseMathTableDefinition({
    required this.id,
    required this.title,
    required this.kind,
    required this.metrics,
    this.entityNamePool = const [],
    this.entityCount = 1,
    this.yearCount = 1,
    this.sharedProductCount = 0,
  });

  final String id;
  final String title;
  final CaseMathTableKind kind;

  /// Metrics (companyYears rows / entityMetric columns / fixedCosts rows).
  final List<CaseMathValueDefinition> metrics;

  /// Pool of display names shuffled into [entityCount] entities.
  final List<String> entityNamePool;
  final int entityCount;
  final int yearCount;

  /// For products table: how many leading products share plant fixed costs.
  final int sharedProductCount;
}

/// Binds a variable used by a question's math expression.
class CaseMathVariableBinding {
  /// Reads a table cell. [entityRef] selects which entity:
  /// - `null` / `focus` → question focus entity
  /// - `shared0` / `shared1` → products that share fixed costs
  /// - `entity:<id>` → specific generated entity id
  /// - a product slot index as `slot0`…
  const CaseMathVariableBinding.value(
    this.valueId, {
    this.tableId,
    this.entityRef,
    this.yearOffset = 0,
    this.format,
  }) : randomRange = null;

  const CaseMathVariableBinding.random(
    this.randomRange, {
    this.format = CaseMathValueFormat.number,
  })  : valueId = null,
        tableId = null,
        entityRef = null,
        yearOffset = 0;

  final String? valueId;
  final String? tableId;
  final String? entityRef;
  final int yearOffset;
  final CaseMathRange? randomRange;
  final CaseMathValueFormat? format;
}

/// A question is fully declarative: text template + variables + arithmetic.
///
/// Supported text tokens: `{company}`, `{product}`, `{year}`, `{previousYear}`,
/// plus any variable name (for example `{upliftPercent}`).
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
    this.focusTableId,
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

  /// Table that supplies the focus entity for `{company}` / `{product}`.
  final String? focusTableId;
}

class CaseMathCaseDefinition {
  const CaseMathCaseDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tables,
    required this.questions,
    this.highScoreKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<CaseMathTableDefinition> tables;
  final List<CaseMathQuestionDefinition> questions;
  final String? highScoreKey;

  CaseMathTableDefinition table(String id) =>
      tables.firstWhere((table) => table.id == id);

  CaseMathValueDefinition value(String valueId) {
    for (final table in tables) {
      for (final metric in table.metrics) {
        if (metric.id == valueId) return metric;
      }
    }
    throw ArgumentError('Unknown value $valueId');
  }

  /// Flat metric list (primarily for Case 1 helpers / tests).
  List<CaseMathValueDefinition> get values => [
        for (final table in tables) ...table.metrics,
      ];
}

/// Runtime entity inside a table (company, product, or cost line).
class CaseMathEntityData {
  const CaseMathEntityData({
    required this.id,
    required this.name,
    required this.values,
  });

  final String id;
  final String name;

  /// metricId → series (length = yearCount, or 1 for non-year tables).
  final Map<String, List<double>> values;

  List<double> series(String valueId) => values[valueId]!;
  double at(String valueId, [int yearIndex = 0]) =>
      values[valueId]![yearIndex];
}

/// One generated table ready for display.
class CaseMathTableView {
  const CaseMathTableView({
    required this.definition,
    required this.yearLabels,
    required this.entities,
    required this.displayMetrics,
  });

  final CaseMathTableDefinition definition;
  final List<String> yearLabels;
  final List<CaseMathEntityData> entities;
  final List<CaseMathValueDefinition> displayMetrics;

  CaseMathEntityData entity(String id) =>
      entities.firstWhere((entity) => entity.id == id);
}

/// Round payload: one or more table views plus shared lookup helpers.
class CaseMathRoundTable {
  const CaseMathRoundTable({
    required this.definition,
    required this.views,
    this.sharedProductIds = const [],
  });

  final CaseMathCaseDefinition definition;
  final List<CaseMathTableView> views;

  /// Product entity ids that share plant fixed costs (Case 2).
  final List<String> sharedProductIds;

  CaseMathTableView view(String tableId) =>
      views.firstWhere((view) => view.definition.id == tableId);

  CaseMathTableView get primaryView => views.first;

  /// Case 1 compatibility: first (company) view entities.
  List<CaseMathEntityData> get companies => primaryView.entities;

  List<String> get yearLabels => primaryView.yearLabels;

  List<CaseMathValueDefinition> get displayValues => primaryView.displayMetrics;

  CaseMathEntityData company(String id) => primaryView.entity(id);
}

class CaseMathQuestion {
  const CaseMathQuestion({
    required this.definition,
    required this.companyId,
    required this.yearIndex,
    required this.prompt,
    required this.variables,
    required this.variableFormats,
    this.focusTableId,
  });

  final CaseMathQuestionDefinition definition;

  /// Focus entity id (`company` / `product`).
  final String companyId;
  final int yearIndex;
  final String prompt;
  final Map<String, double> variables;
  final Map<String, CaseMathValueFormat> variableFormats;
  final String? focusTableId;
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
    this.tableId,
    this.entityId,
  });

  final String variableName;
  final String valueId;
  final int yearIndex;
  final String metricName;
  final String formattedValue;
  final String? tableId;
  final String? entityId;

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
    this.rawPoints,
    this.calculatorPenalty = 0,
  });

  final bool correct;
  final double guess;
  final double exact;
  final double relativeError;

  /// Points awarded after calculator digit penalty (never negative).
  final int points;

  /// Points before calculator penalty. Defaults to [points] when omitted.
  final int? rawPoints;

  /// Amount subtracted for calculator digits (capped by raw points).
  final int calculatorPenalty;
}

/// A successful calculator evaluation (`expression` → `result`).
class CaseMathComputation {
  const CaseMathComputation({
    required this.expression,
    required this.result,
  });

  final String expression;
  final double result;

  @override
  bool operator ==(Object other) {
    return other is CaseMathComputation &&
        other.expression == expression &&
        other.result == result;
  }

  @override
  int get hashCode => Object.hash(expression, result);
}

/// Alias kept for older call sites / readability.
typedef CaseMathCompanyData = CaseMathEntityData;

import 'dart:math';

import 'package:solo_level_system/utils/case_math/case_math_expression.dart';
import 'package:solo_level_system/utils/case_math/case_math_highlights.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

/// Generates any case from its table and question definitions.
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

  /// tableId → shuffled metrics for display.
  late Map<String, List<CaseMathValueDefinition>> _displayMetrics;

  /// Call once when a game session starts (not between questions).
  void reshuffleDisplayOrder() {
    _displayMetrics = {
      for (final table in definition.tables)
        table.id: [...table.metrics]..shuffle(_random),
    };
  }

  CaseMathRound nextRound() {
    final views = <CaseMathTableView>[];
    final sharedProductIds = <String>[];

    for (final tableDef in definition.tables) {
      final view = _generateTableView(tableDef);
      views.add(view);
      if (tableDef.kind == CaseMathTableKind.entityMetric &&
          tableDef.sharedProductCount > 0) {
        sharedProductIds.addAll(
          view.entities
              .take(tableDef.sharedProductCount)
              .map((entity) => entity.id),
        );
      }
    }

    final table = CaseMathRoundTable(
      definition: definition,
      views: views,
      sharedProductIds: List.unmodifiable(sharedProductIds),
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
      variableUsageCount: CaseMathScoring.countVariableUsages(
        question.definition.math,
        question.variables.keys,
      ),
      highlights: highlights,
      solutionParts: solutionParts,
    );
    return CaseMathRound(table: table, question: question, answer: answer);
  }

  CaseMathTableView _generateTableView(CaseMathTableDefinition tableDef) {
    final yearCount = max(1, tableDef.yearCount);
    final startYear = 2019 + _random.nextInt(5);
    final years = tableDef.kind == CaseMathTableKind.companyYears
        ? List.generate(yearCount, (index) => '${startYear + index}')
        : const <String>['Amount'];

    final entities = <CaseMathEntityData>[];
    if (tableDef.kind == CaseMathTableKind.fixedCosts) {
      for (final metric in tableDef.metrics) {
        entities.add(
          CaseMathEntityData(
            id: metric.id,
            name: metric.name,
            values: {
              'amount': [_makeUgly(_randomIn(metric.range), metric.decimalPlaces)],
            },
          ),
        );
      }
    } else {
      final names = [...tableDef.entityNamePool]..shuffle(_random);
      final count = min(tableDef.entityCount, names.length);
      for (var index = 0; index < count; index++) {
        entities.add(
          _generateEntity(
            id: tableDef.kind == CaseMathTableKind.companyYears
                ? String.fromCharCode(65 + index)
                : 'p$index',
            name: names[index],
            metrics: tableDef.metrics,
            yearCount: yearCount,
          ),
        );
      }
    }

    final displayMetrics = tableDef.kind == CaseMathTableKind.fixedCosts
        ? [
            const CaseMathValueDefinition(
              id: 'amount',
              name: 'Amount',
              caseId: '',
              range: CaseMathRange(0, 0),
              format: CaseMathValueFormat.price,
            ),
          ]
        : List<CaseMathValueDefinition>.unmodifiable(
            _displayMetrics[tableDef.id]!,
          );

    return CaseMathTableView(
      definition: tableDef,
      yearLabels: years,
      entities: entities,
      displayMetrics: displayMetrics,
    );
  }

  CaseMathEntityData _generateEntity({
    required String id,
    required String name,
    required List<CaseMathValueDefinition> metrics,
    required int yearCount,
  }) {
    return CaseMathEntityData(
      id: id,
      name: name,
      values: {
        for (final metric in metrics)
          metric.id: _generateSeries(metric, yearCount),
      },
    );
  }

  List<double> _generateSeries(
    CaseMathValueDefinition definition,
    int yearCount,
  ) {
    final values = <double>[];
    var current = _randomIn(definition.range);
    for (var year = 0; year < yearCount; year++) {
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
    final focusTableId =
        definition.focusTableId ?? table.views.first.definition.id;
    final focusView = table.view(focusTableId);

    CaseMathEntityData focusEntity;
    if (focusView.definition.kind == CaseMathTableKind.fixedCosts) {
      focusEntity = focusView.entities.first;
    } else {
      focusEntity =
          focusView.entities[_random.nextInt(focusView.entities.length)];
    }

    final yearCount = focusView.yearLabels.length;
    final availableYears =
        max(1, yearCount - definition.minimumPreviousYears);
    final yearIndex =
        definition.minimumPreviousYears + _random.nextInt(availableYears);

    final variables = <String, double>{};
    final variableFormats = <String, CaseMathValueFormat>{};
    final bindingEntities = <String, String>{};

    for (final entry in definition.variables.entries) {
      final binding = entry.value;
      if (binding.valueId == null) {
        variableFormats[entry.key] =
            binding.format ?? CaseMathValueFormat.number;
        variables[entry.key] = _randomParameter(binding.randomRange!);
        continue;
      }

      final resolved = _resolveCell(
        table: table,
        binding: binding,
        focusEntity: focusEntity,
        focusTableId: focusTableId,
        yearIndex: yearIndex,
      );
      variables[entry.key] = resolved.value;
      variableFormats[entry.key] = resolved.format;
      bindingEntities[entry.key] = resolved.entityId;
    }

    final focusLabel = focusView.definition.kind == CaseMathTableKind.entityMetric
        ? '{product}'
        : '{company}';
    var prompt = definition.questionText
        .replaceAll('{company}', focusEntity.name)
        .replaceAll('{product}', focusEntity.name)
        .replaceAll('{companyId}', focusEntity.id)
        .replaceAll(focusLabel, focusEntity.name)
        .replaceAll('{year}', focusView.yearLabels[yearIndex])
        .replaceAll(
          '{previousYear}',
          focusView.yearLabels[max(0, yearIndex - 1)],
        );

    // Named shared products for prompts.
    if (table.sharedProductIds.isNotEmpty) {
      final products = table.view(
        definition.focusTableId ??
            table.views
                .firstWhere(
                  (view) =>
                      view.definition.kind == CaseMathTableKind.entityMetric,
                )
                .definition
                .id,
      );
      for (var i = 0; i < table.sharedProductIds.length; i++) {
        final entity = products.entity(table.sharedProductIds[i]);
        prompt = prompt
            .replaceAll('{sharedProduct$i}', entity.name)
            .replaceAll('{shared$i}', entity.name);
      }
    }

    for (final entry in variables.entries) {
      final text = CaseMathScoring.formatValue(
        entry.value,
        variableFormats[entry.key]!,
      );
      prompt = prompt.replaceAll('{${entry.key}}', text);
    }

    return CaseMathQuestion(
      definition: definition,
      companyId: focusEntity.id,
      yearIndex: yearIndex,
      prompt: prompt,
      variables: variables,
      variableFormats: variableFormats,
      focusTableId: focusTableId,
    );
  }

  ({double value, CaseMathValueFormat format, String entityId}) _resolveCell({
    required CaseMathRoundTable table,
    required CaseMathVariableBinding binding,
    required CaseMathEntityData focusEntity,
    required String focusTableId,
    required int yearIndex,
  }) {
    final tableId = binding.tableId ?? focusTableId;
    final view = table.view(tableId);
    final entity = _entityForRef(
      table: table,
      view: view,
      ref: binding.entityRef,
      focusEntity: focusEntity,
    );

    if (view.definition.kind == CaseMathTableKind.fixedCosts) {
      final lineId = binding.entityRef ?? binding.valueId!;
      final entity = view.entity(lineId);
      final metric = view.definition.metrics.firstWhere(
        (item) => item.id == lineId,
      );
      return (
        value: entity.at('amount'),
        format: binding.format ?? metric.format,
        entityId: entity.id,
      );
    }

    final metric = view.definition.metrics.firstWhere(
      (item) => item.id == binding.valueId,
    );
    final idx = yearIndex + binding.yearOffset;
    return (
      value: entity.at(binding.valueId!, idx),
      format: binding.format ?? metric.format,
      entityId: entity.id,
    );
  }

  CaseMathEntityData _entityForRef({
    required CaseMathRoundTable table,
    required CaseMathTableView view,
    required String? ref,
    required CaseMathEntityData focusEntity,
  }) {
    if (ref == null || ref == 'focus') {
      return view.entities.firstWhere(
        (entity) => entity.id == focusEntity.id,
        orElse: () => view.entities.first,
      );
    }
    if (ref.startsWith('shared')) {
      final index = int.tryParse(ref.replaceFirst('shared', '')) ?? 0;
      final id = table.sharedProductIds[index];
      return view.entity(id);
    }
    if (ref.startsWith('slot')) {
      final index = int.tryParse(ref.replaceFirst('slot', '')) ?? 0;
      return view.entities[index];
    }
    if (ref.startsWith('entity:')) {
      return view.entity(ref.substring('entity:'.length));
    }
    return view.entity(ref);
  }

  double _randomParameter(CaseMathRange range) {
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
    if (definition.tables.isEmpty || definition.questions.isEmpty) {
      throw ArgumentError('A case needs tables and questions');
    }
    final tableIds = definition.tables.map((table) => table.id).toSet();
    if (tableIds.length != definition.tables.length) {
      throw ArgumentError('Case table IDs must be unique');
    }
    final valueIds = <String>{};
    for (final table in definition.tables) {
      if (table.kind != CaseMathTableKind.fixedCosts &&
          table.entityNamePool.length < table.entityCount) {
        throw ArgumentError('Table ${table.id} needs enough entity names');
      }
      for (final metric in table.metrics) {
        if (metric.caseId != definition.id && metric.caseId.isNotEmpty) {
          throw ArgumentError('Metric ${metric.id} has the wrong case ID');
        }
        if (table.kind != CaseMathTableKind.fixedCosts &&
            !valueIds.add('${table.id}:${metric.id}')) {
          throw ArgumentError('Duplicate metric ${metric.id} in ${table.id}');
        }
      }
    }
    for (final question in definition.questions) {
      if (question.caseId != definition.id) {
        throw ArgumentError('Question ${question.id} has the wrong case ID');
      }
      final focusId = question.focusTableId ?? definition.tables.first.id;
      if (!tableIds.contains(focusId)) {
        throw ArgumentError('Question ${question.id} has unknown focus table');
      }
      for (final binding in question.variables.values) {
        if (binding.valueId == null) continue;
        final tableId = binding.tableId ?? focusId;
        if (!tableIds.contains(tableId)) {
          throw ArgumentError(
            'Question ${question.id} references unknown table $tableId',
          );
        }
        final table = definition.table(tableId);
        if (table.kind == CaseMathTableKind.fixedCosts) {
          final ok = table.metrics.any((metric) => metric.id == binding.valueId) ||
              binding.entityRef == binding.valueId ||
              binding.valueId == 'amount';
          if (!ok && binding.entityRef == null) {
            // Allow valueId to be the cost line id via entityRef-less form:
            // valueId names the cost line when table is fixedCosts.
            final lineOk =
                table.metrics.any((metric) => metric.id == binding.valueId);
            if (!lineOk) {
              throw ArgumentError(
                'Question ${question.id} references ${binding.valueId}',
              );
            }
          }
        } else {
          final ok =
              table.metrics.any((metric) => metric.id == binding.valueId);
          if (!ok) {
            throw ArgumentError(
              'Question ${question.id} references ${binding.valueId}',
            );
          }
        }
      }
    }
  }
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_level_system/utils/case_math/case1_definition.dart';
import 'package:solo_level_system/utils/case_math/case_math_expression.dart';
import 'package:solo_level_system/utils/case_math/case_math_generator.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';

void main() {
  group('CaseMathExpression', () {
    test('evaluates variables, precedence, and parentheses', () {
      expect(
        CaseMathExpression.evaluate(
          '(revenue - costs) / revenue * 100',
          {'revenue': 200, 'costs': 150},
        ),
        25,
      );
      expect(
        CaseMathExpression.evaluate('price * units + fee', {
          'price': 19.5,
          'units': 3,
          'fee': 2,
        }),
        60.5,
      );
    });

    test('rejects unknown variables and division by zero', () {
      expect(
        () => CaseMathExpression.evaluate('missing * 2', {}),
        throwsFormatException,
      );
      expect(
        () => CaseMathExpression.evaluate('10 / zero', {'zero': 0}),
        throwsFormatException,
      );
    });
  });

  group('data-defined Case 1', () {
    test('declares ten rows and seven questions under one case ID', () {
      expect(case1Definition.id, 'case_1');
      expect(case1Definition.values, hasLength(10));
      expect(case1Definition.questions, hasLength(7));
      expect(
        case1Definition.values.every((value) => value.caseId == 'case_1'),
        isTrue,
      );
      expect(
        case1Definition.questions.every((q) => q.caseId == 'case_1'),
        isTrue,
      );
    });

    test('generator produces two companies and four years from schema', () {
      final round = CaseMathGenerator(
        definition: case1Definition,
        random: Random(42),
      ).nextRound();
      expect(round.table.definition, same(case1Definition));
      expect(round.table.yearLabels, hasLength(4));
      expect(round.table.companies, hasLength(2));
      expect(round.table.displayValues, hasLength(10));
      expect(
        round.table.displayValues.map((value) => value.id).toSet(),
        case1Definition.values.map((value) => value.id).toSet(),
      );
      for (final company in round.table.companies) {
        expect(
          company.values.keys.toSet(),
          case1Definition.values.map((value) => value.id).toSet(),
        );
        for (final value in case1Definition.values) {
          expect(company.series(value.id), hasLength(4));
        }
      }
    });

    test('row display order is stable across questions until reshuffled', () {
      final generator = CaseMathGenerator(
        definition: case1Definition,
        random: Random(11),
      );
      final first = generator.nextRound().table.displayValues.map((v) => v.id);
      final second = generator.nextRound().table.displayValues.map((v) => v.id);
      expect(second, orderedEquals(first));

      generator.reshuffleDisplayOrder();
      final third = generator.nextRound().table.displayValues.map((v) => v.id);
      expect(third.toSet(), first.toSet());
      expect(third, isNot(orderedEquals(first)));
    });

    test('formula highlights map table cells with distinct colors', () {
      final round = CaseMathGenerator(
        definition: case1Definition,
        random: Random(21),
      ).nextRound();
      expect(round.answer.highlights, isNotEmpty);
      expect(round.answer.solutionParts, isNotEmpty);
      final keys = round.answer.highlights
          .map((h) => '${h.valueId}@${h.yearIndex}')
          .toSet();
      expect(keys.length, round.answer.highlights.length);
      expect(
        round.answer.solutionParts.any((part) => part.highlight != null),
        isTrue,
      );
    });

    test('every generated answer equals its declared expression', () {
      final generator = CaseMathGenerator(
        definition: case1Definition,
        random: Random(7),
      );
      for (var i = 0; i < 80; i++) {
        final round = generator.nextRound();
        final recomputed = CaseMathExpression.evaluate(
          round.question.definition.math,
          round.question.variables,
        );
        expect(round.answer.exact, closeTo(recomputed, 1e-8));
        expect(round.answer.formula, round.question.definition.formula);
        expect(round.question.prompt, isNot(contains('{')));
      }
    });

    test('schema can define a new multiplication case without new logic', () {
      const custom = CaseMathCaseDefinition(
        id: 'case_custom',
        title: 'Custom',
        subtitle: 'Multiplication',
        companyNames: ['One', 'Two'],
        yearCount: 1,
        values: [
          CaseMathValueDefinition(
            id: 'price',
            name: 'Price',
            caseId: 'case_custom',
            range: CaseMathRange(10, 20),
            format: CaseMathValueFormat.price,
          ),
          CaseMathValueDefinition(
            id: 'units',
            name: 'Units',
            caseId: 'case_custom',
            range: CaseMathRange(100, 200),
          ),
        ],
        questions: [
          CaseMathQuestionDefinition(
            id: 'revenue',
            caseId: 'case_custom',
            questionText: 'How much revenue did {company} make in {year}?',
            math: 'price * units',
            formula: 'Revenue = Price × Units',
            answerType: CaseMathValueFormat.price,
            variables: {
              'price': CaseMathVariableBinding.value('price'),
              'units': CaseMathVariableBinding.value('units'),
            },
          ),
        ],
      );
      final round = CaseMathGenerator(
        definition: custom,
        random: Random(3),
      ).nextRound();
      expect(
        round.answer.exact,
        round.question.variables['price']! *
            round.question.variables['units']!,
      );
    });
  });

  group('CaseMathScoring', () {
    test('parses formatted user input', () {
      expect(CaseMathScoring.parseGuess(r'$4,462,719'), 4462719);
      expect(CaseMathScoring.parseGuess('18.71%'), closeTo(18.71, 1e-9));
      expect(CaseMathScoring.parseGuess(''), isNull);
    });

    test('uses relative and percentage tolerances', () {
      const priceAnswer = CaseMathWorkedAnswer(
        exact: 1000000,
        formula: 'f',
        solution: 's',
        type: CaseMathValueFormat.price,
      );
      expect(
        CaseMathScoring.score(
          guess: 1015000,
          answer: priceAnswer,
        ).correct,
        isTrue,
      );
      expect(
        CaseMathScoring.score(
          guess: 1100000,
          answer: priceAnswer,
        ).correct,
        isFalse,
      );

      const percentageAnswer = CaseMathWorkedAnswer(
        exact: 18.71,
        formula: 'f',
        solution: 's',
        type: CaseMathValueFormat.percentage,
      );
      expect(
        CaseMathScoring.score(
          guess: 18.9,
          answer: percentageAnswer,
        ).correct,
        isTrue,
      );
      expect(
        CaseMathScoring.score(
          guess: 20.5,
          answer: percentageAnswer,
        ).correct,
        isFalse,
      );
    });
  });
}

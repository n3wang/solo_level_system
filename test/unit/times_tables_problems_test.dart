import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_level_system/utils/times_tables/times_tables_problems.dart';

void main() {
  group('TimesTablesProblems', () {
    test('never uses 1, 2, or 10 as a factor', () {
      expect(TimesTablesProblems.factors, isNot(contains(1)));
      expect(TimesTablesProblems.factors, isNot(contains(2)));
      expect(TimesTablesProblems.factors, isNot(contains(10)));
      expect(TimesTablesProblems.factors, containsAll([3, 4, 5, 6, 7, 8, 9, 11, 12]));
    });

    test('generated pairs stay in the allowed range', () {
      final random = Random(7);
      TimesTableProblem? previous;
      for (var i = 0; i < 80; i++) {
        final problem = TimesTablesProblems.next(random, avoid: previous);
        expect(TimesTablesProblems.isAllowedPair(problem.a, problem.b), isTrue);
        expect(problem.product, problem.a * problem.b);
        previous = problem;
      }
    });

    test('sameFact treats order as the same multiplication', () {
      expect(
        const TimesTableProblem(7, 8).sameFact(const TimesTableProblem(8, 7)),
        isTrue,
      );
      expect(
        const TimesTableProblem(7, 8).sameFact(const TimesTableProblem(7, 9)),
        isFalse,
      );
    });
  });
}

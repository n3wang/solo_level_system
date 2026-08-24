import 'dart:math';

/// Multiplication facts used by the times-tables race.
///
/// Omits 1, 2, and 10 on either side — those are treated as too easy.
class TimesTablesProblems {
  TimesTablesProblems._();

  static const excludedFactors = {1, 2, 10};
  static const minFactor = 3;
  static const maxFactor = 12;

  static List<int> get factors => [
        for (var n = minFactor; n <= maxFactor; n++)
          if (!excludedFactors.contains(n)) n,
      ];

  static bool isAllowedPair(int a, int b) {
    return !excludedFactors.contains(a) &&
        !excludedFactors.contains(b) &&
        a >= minFactor &&
        b >= minFactor &&
        a <= maxFactor &&
        b <= maxFactor;
  }

  static TimesTableProblem next(
    Random random, {
    TimesTableProblem? avoid,
  }) {
    final pool = factors;
    TimesTableProblem problem;
    var attempts = 0;
    do {
      final a = pool[random.nextInt(pool.length)];
      final b = pool[random.nextInt(pool.length)];
      problem = TimesTableProblem(a, b);
      attempts++;
    } while (avoid != null && problem.sameFact(avoid) && attempts < 20);
    return problem;
  }
}

class TimesTableProblem {
  const TimesTableProblem(this.a, this.b);

  final int a;
  final int b;

  int get product => a * b;

  String get prompt => '$a × $b';

  bool sameFact(TimesTableProblem other) =>
      (a == other.a && b == other.b) || (a == other.b && b == other.a);
}

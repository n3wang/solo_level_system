import 'dart:math' as math;

import 'package:solo_level_system/utils/case_math/case_math_models.dart';

class CaseMathScoring {
  CaseMathScoring._();

  static const double relativeTolerance = 0.02;
  static const double absoluteTolerance = 0.05;

  static CaseMathScoreResult score({
    required double guess,
    required CaseMathWorkedAnswer answer,
  }) {
    final exact = answer.exact;
    final absoluteError = (guess - exact).abs();
    final relativeError =
        exact.abs() < 1e-9 ? absoluteError : absoluteError / exact.abs();
    final tolerance = answer.type == CaseMathValueFormat.percentage
        ? math.max(0.5, exact.abs() * relativeTolerance)
        : math.max(absoluteTolerance, exact.abs() * relativeTolerance);
    final correct = absoluteError <= tolerance;
    final points = correct
        ? (relativeError <= 0.005
            ? 1000
            : (relativeError <= relativeTolerance ? 750 : 500))
        : 0;
    return CaseMathScoreResult(
      correct: correct,
      guess: guess,
      exact: exact,
      relativeError: relativeError,
      points: points,
    );
  }

  static double? parseGuess(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .replaceAll('−', '-');
    return double.tryParse(value);
  }

  static String buildSolution(CaseMathQuestion question, double exact) {
    var substituted = question.definition.math;
    final names = question.variables.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      substituted = substituted.replaceAll(
        RegExp('\\b${RegExp.escape(name)}\\b'),
        formatValue(question.variables[name]!, question.variableFormats[name]!),
      );
    }
    return '$substituted = '
        '${formatValue(exact, question.definition.answerType)}';
  }

  static String formatValue(double value, CaseMathValueFormat format) {
    return switch (format) {
      CaseMathValueFormat.price => _money(value),
      CaseMathValueFormat.percentage => '${value.toStringAsFixed(2)}%',
      CaseMathValueFormat.number => _number(value),
    };
  }

  static String _money(double value) {
    final negative = value < 0;
    final absolute = value.abs();
    final whole = absolute.floor();
    final fraction = absolute - whole;
    final wholeText = _withCommas(whole);
    final prefix = negative ? '-\$' : '\$';
    if (fraction < 0.005) return '$prefix$wholeText';
    final cents = (fraction * 100).round().toString().padLeft(2, '0');
    return '$prefix$wholeText.$cents';
  }

  static String _number(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return _withCommas(value.round());
    }
    return value.toStringAsFixed(2);
  }

  static String _withCommas(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }
}

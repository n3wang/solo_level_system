import 'dart:math' as math;

import 'package:solo_level_system/utils/case_math/case_math_models.dart';

class CaseMathScoring {
  CaseMathScoring._();

  /// Relative error allowed per variable usage for partial credit.
  static const double acceptTolerancePerUsage = 0.025;

  /// Relative error allowed per variable usage for full credit.
  static const double preciseTolerancePerUsage = 0.01;

  /// Near-zero exact answers use this absolute floor instead of relative %.
  static const double absoluteTolerance = 0.05;

  /// Maps-adjacent per-round tiers (5×1000 ≈ Chrono Atlas top geo band).
  static const int precisePoints = 1000;
  static const int acceptPoints = 500;

  /// Points removed per calculator digit typed while solving.
  static const int calculatorDigitPenalty = 60;

  /// Relative error allowed when recalling a calculator result.
  static const double recallRelativeTolerance = 0.03;

  /// Absolute floor for near-zero recall answers.
  static const double recallAbsoluteTolerance = 0.05;

  /// Points awarded for each correct calculator-recall answer.
  static const int recallRewardPoints = 10;

  static CaseMathScoreResult score({
    required double guess,
    required CaseMathWorkedAnswer answer,
    int calculatorDigitsUsed = 0,
  }) {
    final exact = answer.exact;
    final usages = math.max(1, answer.variableUsageCount);
    final absoluteError = (guess - exact).abs();
    final relativeError =
        exact.abs() < 1e-9 ? absoluteError : absoluteError / exact.abs();

    final acceptTol = acceptTolerancePerUsage * usages;
    final preciseTol = preciseTolerancePerUsage * usages;

    final withinAccept = exact.abs() < 1e-9
        ? absoluteError <= absoluteTolerance
        : relativeError <= acceptTol;
    final withinPrecise = exact.abs() < 1e-9
        ? absoluteError <= absoluteTolerance * 0.4
        : relativeError <= preciseTol;

    final rawPoints = !withinAccept
        ? 0
        : (withinPrecise ? precisePoints : acceptPoints);
    final penalty = applyCalculatorPenalty(
      digitEntries: calculatorDigitsUsed,
    );
    final points = math.max(0, rawPoints - penalty);

    return CaseMathScoreResult(
      correct: withinAccept,
      guess: guess,
      exact: exact,
      relativeError: relativeError,
      points: points,
      rawPoints: rawPoints,
      calculatorPenalty: math.min(penalty, rawPoints),
    );
  }

  static int applyCalculatorPenalty({
    required int digitEntries,
    int perDigit = calculatorDigitPenalty,
  }) {
    if (digitEntries <= 0) return 0;
    return digitEntries * perDigit;
  }

  /// Whether [guess] is close enough to [exact] for calculator recall.
  ///
  /// Both values are rounded to 2 decimals first (human-scale precision), then
  /// compared with ±[recallRelativeTolerance] (or the near-zero absolute floor).
  static bool isRecallCorrect({
    required double guess,
    required double exact,
  }) {
    final roundedGuess = roundToRecallPrecision(guess);
    final roundedExact = roundToRecallPrecision(exact);
    final absoluteError = (roundedGuess - roundedExact).abs();
    if (roundedExact.abs() < 1e-9) {
      return absoluteError <= recallAbsoluteTolerance;
    }
    return absoluteError / roundedExact.abs() <= recallRelativeTolerance;
  }

  /// Rounds to 2 decimal places for recall grading and display.
  static double roundToRecallPrecision(double value) {
    return (value * 100).round() / 100;
  }

  /// Human-scale recall number (2 decimals, trailing zeros trimmed).
  static String formatRecallNumber(double value) {
    final rounded = roundToRecallPrecision(value);
    if ((rounded - rounded.roundToDouble()).abs() < 1e-9) {
      return withThousandSeparators(rounded.round().toString());
    }
    var text = rounded.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return withThousandSeparators(text);
  }

  /// Appends [item] only when an identical expression/result is not already
  /// present (avoids duplicate drills from repeated `=` presses).
  static void recordUniqueComputation(
    List<CaseMathComputation> history,
    CaseMathComputation item,
  ) {
    if (!history.contains(item)) history.add(item);
  }

  /// Wrong answers move to the end; correct answers are removed.
  static void advanceRecallQueue<T>({
    required List<T> queue,
    required bool correct,
  }) {
    if (queue.isEmpty) return;
    final current = queue.removeAt(0);
    if (!correct) queue.add(current);
  }

  /// Counts how many times [variableNames] appear as tokens in [expression].
  static int countVariableUsages(
    String expression,
    Iterable<String> variableNames,
  ) {
    var count = 0;
    final names = variableNames.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      count +=
          RegExp('\\b${RegExp.escape(name)}\\b').allMatches(expression).length;
    }
    return math.max(1, count);
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
      CaseMathValueFormat.percentage =>
        '${withThousandSeparators(value.toStringAsFixed(2))}%',
      CaseMathValueFormat.number => _number(value),
    };
  }

  /// Adds commas every 3 digits in the integer part only.
  /// Preserves leading `-`, a decimal point, and the fractional digits.
  /// Examples: `1234` → `1,234`, `-1234.5` → `-1,234.5`, `1234.` → `1,234.`
  static String withThousandSeparators(String raw) {
    if (raw.isEmpty || raw == '-' || raw == '.' || raw == '-.') return raw;
    final negative = raw.startsWith('-');
    final body = negative ? raw.substring(1) : raw;
    final dot = body.indexOf('.');
    final intDigits = dot < 0 ? body : body.substring(0, dot);
    final fraction = dot < 0 ? null : body.substring(dot); // includes '.'
    if (intDigits.isNotEmpty && !RegExp(r'^\d+$').hasMatch(intDigits)) {
      return raw;
    }
    if (fraction != null &&
        fraction.length > 1 &&
        !RegExp(r'^\.\d*$').hasMatch(fraction)) {
      return raw;
    }
    final formattedInt =
        intDigits.isEmpty ? '' : _withCommasFromDigits(intDigits);
    return '${negative ? '-' : ''}$formattedInt${fraction ?? ''}';
  }

  /// Formats each numeric literal in an expression (operators unchanged).
  static String withThousandSeparatorsInExpression(String expression) {
    return expression.replaceAllMapped(
      RegExp(r'\d+\.?\d*'),
      (match) => withThousandSeparators(match.group(0)!),
    );
  }

  static String _money(double value) {
    final negative = value < 0;
    // Round to cents first so 5.998 → $6, not "$5.100".
    final centsTotal = (value.abs() * 100).round();
    final whole = centsTotal ~/ 100;
    final cents = centsTotal % 100;
    final wholeText = _withCommas(whole);
    final prefix = negative ? '-\$' : '\$';
    if (cents == 0) return '$prefix$wholeText';
    return '$prefix$wholeText.${cents.toString().padLeft(2, '0')}';
  }

  static String _number(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return _withCommas(value.round());
    }
    return withThousandSeparators(value.toStringAsFixed(2));
  }

  static String _withCommas(int value) {
    final formatted = _withCommasFromDigits(value.abs().toString());
    return value < 0 ? '-$formatted' : formatted;
  }

  static String _withCommasFromDigits(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

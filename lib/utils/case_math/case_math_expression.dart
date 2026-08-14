/// Small, safe arithmetic evaluator for data-defined Case Math questions.
///
/// Supports numbers, variables, parentheses, and `+`, `-`, `*`, `/`.
class CaseMathExpression {
  CaseMathExpression._();

  static double evaluate(String expression, Map<String, double> variables) {
    final parser = _ExpressionParser(expression, variables);
    final value = parser.parse();
    if (!value.isFinite) {
      throw FormatException('Expression produced a non-finite value');
    }
    return value;
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source, this.variables);

  final String source;
  final Map<String, double> variables;
  int index = 0;

  double parse() {
    final result = _expression();
    _skipWhitespace();
    if (index != source.length) {
      throw FormatException('Unexpected token at position $index');
    }
    return result;
  }

  double _expression() {
    var value = _term();
    while (true) {
      _skipWhitespace();
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _factor();
    while (true) {
      _skipWhitespace();
      if (_consume('*')) {
        value *= _factor();
      } else if (_consume('/')) {
        final divisor = _factor();
        if (divisor == 0) throw FormatException('Division by zero');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    _skipWhitespace();
    if (_consume('-')) return -_factor();
    if (_consume('+')) return _factor();
    if (_consume('(')) {
      final value = _expression();
      _skipWhitespace();
      if (!_consume(')')) {
        throw FormatException('Missing closing parenthesis');
      }
      return value;
    }
    if (index < source.length &&
        (source.codeUnitAt(index) >= 48 && source.codeUnitAt(index) <= 57 ||
            source[index] == '.')) {
      return _number();
    }
    return _variable();
  }

  double _number() {
    final start = index;
    while (index < source.length) {
      final char = source[index];
      if ((char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) ||
          char == '.') {
        index++;
      } else {
        break;
      }
    }
    final value = double.tryParse(source.substring(start, index));
    if (value == null) throw FormatException('Invalid number at $start');
    return value;
  }

  double _variable() {
    final start = index;
    while (index < source.length) {
      final char = source[index];
      final code = char.codeUnitAt(0);
      final valid = code >= 65 && code <= 90 ||
          code >= 97 && code <= 122 ||
          code >= 48 && code <= 57 ||
          char == '_';
      if (!valid) break;
      index++;
    }
    if (start == index) {
      throw FormatException('Expected value at position $index');
    }
    final name = source.substring(start, index);
    final value = variables[name];
    if (value == null) throw FormatException('Unknown variable "$name"');
    return value;
  }

  bool _consume(String char) {
    if (index < source.length && source[index] == char) {
      index++;
      return true;
    }
    return false;
  }

  void _skipWhitespace() {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_expression.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/games/case_math_keypad.dart';

/// Compact solution calculator: digits + + − × ÷ ( ) = C.
/// Transparent chrome — only keys / display are opaque so content below shows.
/// Table cell and results-list taps insert values via [insertValue].
class CaseMathCalculator extends StatefulWidget {
  const CaseMathCalculator({
    super.key,
    this.width = 208,
    this.historyWidth = 88,
  });

  final double width;
  final double historyWidth;

  @override
  State<CaseMathCalculator> createState() => CaseMathCalculatorState();
}

class CaseMathCalculatorState extends State<CaseMathCalculator> {
  String _expression = '';
  String? _error;
  double? _result;
  final List<String> _history = [];
  final _historyScroll = ScrollController();

  String get expression => _expression;

  @override
  void dispose() {
    _historyScroll.dispose();
    super.dispose();
  }

  void clear({bool clearHistory = false}) {
    setState(() {
      _expression = '';
      _error = null;
      _result = null;
      if (clearHistory) _history.clear();
    });
  }

  /// Clears pad + history (e.g. when advancing to the next question).
  void resetForNewQuestion() => clear(clearHistory: true);

  /// Insert a table cell value as the next operand.
  void insertValue(double value) {
    final text = _formatInsert(value);
    setState(() {
      _error = null;
      _result = null;
      if (_expression.isEmpty || _endsWithOperatorOrParenOpen) {
        _expression += text;
      } else {
        _expression += '*$text';
      }
    });
  }

  bool get _endsWithOperatorOrParenOpen {
    if (_expression.isEmpty) return true;
    final last = _expression[_expression.length - 1];
    return '+-*/('.contains(last);
  }

  void _append(String token) {
    setState(() {
      _error = null;
      _result = null;
      if (token == '.' && _currentNumberContainsDecimal) return;
      if (_isOperator(token) && _expression.isEmpty) return;
      if (_isOperator(token) && _endsWithOperatorOrParenOpen) {
        if (token == '-' && _expression.endsWith('(')) {
          _expression += token;
          return;
        }
        if (_isOperator(_expression[_expression.length - 1])) {
          _expression =
              '${_expression.substring(0, _expression.length - 1)}$token';
          return;
        }
      }
      _expression += token;
    });
  }

  bool get _currentNumberContainsDecimal {
    final match = RegExp(r'[0-9.]+$').firstMatch(_expression);
    return match != null && match.group(0)!.contains('.');
  }

  bool _isOperator(String token) =>
      token == '+' || token == '-' || token == '*' || token == '/';

  void _backspace() {
    if (_expression.isEmpty) return;
    setState(() {
      _error = null;
      _result = null;
      _expression = _expression.substring(0, _expression.length - 1);
    });
  }

  void _evaluate() {
    if (_expression.trim().isEmpty) return;
    try {
      final value = CaseMathExpression.evaluate(_expression, const {});
      final formatted = _formatInsert(value);
      setState(() {
        _result = value;
        _error = null;
        _expression = formatted;
        _history.add(formatted);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_historyScroll.hasClients) return;
        _historyScroll.jumpTo(_historyScroll.position.maxScrollExtent);
      });
    } catch (_) {
      setState(() {
        _error = 'Invalid';
        _result = null;
      });
    }
  }

  /// Handles hardware / software keyboard input. Returns true if consumed.
  bool handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspace();
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _evaluate();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      clear();
      return true;
    }

    final token = _tokenForHardwareKey(event);
    if (token == null) return false;
    if (token == '=') {
      _evaluate();
      return true;
    }
    if (token == 'C') {
      clear();
      return true;
    }
    _append(token);
    return true;
  }

  String? _tokenForHardwareKey(KeyEvent event) {
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      if (RegExp(r'^[0-9]$').hasMatch(character)) return character;
      switch (character) {
        case '.':
          return '.';
        case '+':
          return '+';
        case '-':
        case '−':
          return '-';
        case '*':
        case 'x':
        case 'X':
        case '×':
          return '*';
        case '/':
        case '÷':
          return '/';
        case '(':
          return '(';
        case ')':
          return ')';
        case '=':
          return '=';
        case 'c':
        case 'C':
          return 'C';
      }
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.numpadAdd) return '+';
    if (key == LogicalKeyboardKey.numpadSubtract) return '-';
    if (key == LogicalKeyboardKey.numpadMultiply) return '*';
    if (key == LogicalKeyboardKey.numpadDivide) return '/';
    if (key == LogicalKeyboardKey.numpadDecimal) return '.';
    if (key == LogicalKeyboardKey.numpadEqual) return '=';
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return '0';
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return '1';
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return '2';
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return '3';
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return '4';
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      return '5';
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      return '6';
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      return '7';
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return '8';
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return '9';
    }
    return null;
  }

  String _formatInsert(double value) {
    if ((value - value.roundToDouble()).abs() < 1e-9) {
      return value.round().toString();
    }
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return _HitTestPassthrough(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CalcSurface(
                  surface: surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _expression.isEmpty
                            ? '0'
                            : CaseMathScoring.withThousandSeparatorsInExpression(
                                _expression,
                              ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _expression.isEmpty
                              ? AppColorPalette.textSecondary
                              : null,
                        ),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColorPalette.error,
                          ),
                        )
                      else if (_result != null)
                        Text(
                          '= ${CaseMathScoring.withThousandSeparators(_formatInsert(_result!))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColorPalette.textSecondary,
                          ),
                        )
                      else
                        Text(
                          'Tap table cells to fill',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColorPalette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CaseMathDigitPad(
                        compact: true,
                        opaqueKeys: true,
                        onKeyTap: _append,
                        onBackspace: _backspace,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          for (final op in const ['/', '*', '-', '+']) ...[
                            SizedBox(
                              height: 36,
                              width: double.infinity,
                              child: CaseMathKeypadButton(
                                label: op == '*'
                                    ? '×'
                                    : op == '/'
                                        ? '÷'
                                        : op,
                                compact: true,
                                opaque: true,
                                onPressed: () => _append(op),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final entry in [
                      ('(', () => _append('(')),
                      (')', () => _append(')')),
                      ('C', () => clear()),
                      ('=', _evaluate),
                    ].indexed) ...[
                      if (entry.$1 > 0) const SizedBox(width: 4),
                      Expanded(
                        child: CaseMathKeypadButton(
                          label: entry.$2.$1,
                          compact: true,
                          opaque: true,
                          onPressed: entry.$2.$2,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: widget.historyWidth,
            child: _CalcHistoryBox(
              surface: surface,
              history: _history,
              scrollController: _historyScroll,
              onResultTap: (text) {
                final value = double.tryParse(text);
                if (value == null) return;
                insertValue(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalcSurface extends StatelessWidget {
  const _CalcSurface({
    required this.surface,
    required this.child,
  });

  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
        ),
        child: child,
      ),
    );
  }
}

class _CalcHistoryBox extends StatelessWidget {
  const _CalcHistoryBox({
    required this.surface,
    required this.history,
    required this.scrollController,
    required this.onResultTap,
  });

  final Color surface;
  final List<String> history;
  final ScrollController scrollController;
  final ValueChanged<String> onResultTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Material(
        color: surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Results',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColorPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: history.isEmpty
                    ? Text(
                        'Press =',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColorPalette.textSecondary,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final n = index + 1;
                          final text = history[index];
                          return InkWell(
                            onTap: () => onResultTap(text),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3,
                              ),
                              child: Text(
                                '$n. ${CaseMathScoring.withThousandSeparators(text)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle chip for the calculator. Body floats separately via [overlay].
class CaseMathCalculatorPanel extends StatelessWidget {
  const CaseMathCalculatorPanel({
    super.key,
    required this.visible,
    required this.onVisibilityChanged,
    required this.calculatorKey,
  });

  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;
  final GlobalKey<CaseMathCalculatorState> calculatorKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        SettingsRectChip(
          label: visible ? 'Hide Calc' : 'Calculator',
          icon: Icons.calculate_outlined,
          selected: visible,
          size: SettingsRectChipSize.compact,
          onTap: () {
            final next = !visible;
            if (!next) calculatorKey.currentState?.clear();
            onVisibilityChanged(next);
          },
        ),
      ],
    );
  }
}

/// Lets taps miss empty space and fall through to widgets below a [Stack].
class _HitTestPassthrough extends SingleChildRenderObjectWidget {
  const _HitTestPassthrough({required Widget child}) : super(child: child);

  @override
  RenderHitTestPassthrough createRenderObject(BuildContext context) {
    return RenderHitTestPassthrough();
  }
}

class RenderHitTestPassthrough extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }
}

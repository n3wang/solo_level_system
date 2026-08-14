import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_expression.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/games/case_math_keypad.dart';

/// Compact solution calculator: digits + + − × ÷ ( ) = C.
/// Transparent chrome — only keys / display are opaque so content below shows.
/// Table cell taps insert values via [insertValue].
class CaseMathCalculator extends StatefulWidget {
  const CaseMathCalculator({
    super.key,
    this.width = 208,
  });

  final double width;

  @override
  State<CaseMathCalculator> createState() => CaseMathCalculatorState();
}

class CaseMathCalculatorState extends State<CaseMathCalculator> {
  String _expression = '';
  String? _error;
  double? _result;

  String get expression => _expression;

  void clear() {
    setState(() {
      _expression = '';
      _error = null;
      _result = null;
    });
  }

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
      setState(() {
        _result = value;
        _error = null;
        _expression = _formatInsert(value);
      });
    } catch (_) {
      setState(() {
        _error = 'Invalid';
        _result = null;
      });
    }
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
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: surface,
              elevation: 1,
              borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? '0' : _expression,
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
                        '= ${_formatInsert(_result!)}',
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
                  ('C', clear),
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

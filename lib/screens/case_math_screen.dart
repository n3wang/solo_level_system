import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case1_definition.dart';
import 'package:solo_level_system/utils/case_math/case_math_generator.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/utils/case_math/case_math_scoring.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/games/case_math_calculator.dart';
import 'package:solo_level_system/widgets/games/case_math_formulas_modal.dart';
import 'package:solo_level_system/widgets/games/case_math_keypad.dart';
import 'package:solo_level_system/widgets/games/case_math_table.dart';
import 'package:solo_level_system/widgets/games/retro_scoreboard.dart';

enum _CaseMathPhase { guess, reveal, summary }

enum _InputMode { system, pad, mini }

/// Fixed mini keypad / Check / Next width so reveal does not jump.
const double _caseMathMiniActionWidth = 168;

/// Minimal Case Math mini-game — Case 1 coffee chain (extensible later).
class CaseMathScreen extends StatefulWidget {
  const CaseMathScreen({
    super.key,
    this.roundsPerSession = 5,
    this.exitLabel = 'Back to games',
  });

  final int roundsPerSession;
  final String exitLabel;

  static const highScoreKey = 'case_math_high_scores';

  @override
  State<CaseMathScreen> createState() => _CaseMathScreenState();
}

class _CaseMathScreenState extends State<CaseMathScreen> {
  final _generator = CaseMathGenerator(definition: case1Definition);
  final _systemAnswerController = TextEditingController();
  final _systemAnswerFocus = FocusNode();
  final _calculatorKey = GlobalKey<CaseMathCalculatorState>();

  late CaseMathRound _round;
  _CaseMathPhase _phase = _CaseMathPhase.guess;
  int _roundIndex = 0;
  int _sessionScore = 0;
  int _selectedCompanyIndex = 0;
  _InputMode _inputMode = _InputMode.mini;
  bool _calculatorVisible = false;
  String _answerText = '';
  CaseMathScoreResult? _lastScore;
  String? _parseError;

  List<_CaseMathHighScore> _highScores = const [];
  int? _highlightHighScoreIndex;

  @override
  void initState() {
    super.initState();
    _round = _generator.nextRound();
  }

  @override
  void dispose() {
    _systemAnswerController.dispose();
    _systemAnswerFocus.dispose();
    super.dispose();
  }

  void _setAnswerText(String value) {
    _answerText = value;
    if (_systemAnswerController.text != value) {
      _systemAnswerController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _clearAnswer() {
    _setAnswerText('');
    _parseError = null;
  }

  Future<void> _checkAnswer() async {
    final parsed = CaseMathScoring.parseGuess(_answerText);
    if (parsed == null) {
      setState(() => _parseError = 'Enter a number');
      return;
    }
    final result = CaseMathScoring.score(guess: parsed, answer: _round.answer);
    final companyIndex = _round.table.companies.indexWhere(
      (company) => company.id == _round.question.companyId,
    );
    setState(() {
      _parseError = null;
      _lastScore = result;
      _sessionScore += result.points;
      _phase = _CaseMathPhase.reveal;
      _calculatorVisible = false;
      if (companyIndex >= 0) _selectedCompanyIndex = companyIndex;
    });
  }

  void _showQuestionCompany() {
    final companyIndex = _round.table.companies.indexWhere(
      (company) => company.id == _round.question.companyId,
    );
    if (companyIndex < 0 || companyIndex == _selectedCompanyIndex) return;
    setState(() => _selectedCompanyIndex = companyIndex);
  }

  Future<void> _next() async {
    if (_roundIndex + 1 >= widget.roundsPerSession) {
      final recorded = await _CaseMathHighScores.record(
        score: _sessionScore,
        at: DateTime.now(),
        storageKey: CaseMathScreen.highScoreKey,
      );
      if (!mounted) return;
      setState(() {
        _phase = _CaseMathPhase.summary;
        _highScores = recorded.board;
        _highlightHighScoreIndex = recorded.insertedIndex;
      });
      return;
    }
    setState(() {
      _roundIndex += 1;
      _round = _generator.nextRound();
      _clearAnswer();
      _selectedCompanyIndex = 0;
      _lastScore = null;
      _calculatorVisible = false;
      _phase = _CaseMathPhase.guess;
    });
  }

  void _restart() {
    setState(() {
      _roundIndex = 0;
      _sessionScore = 0;
      _generator.reshuffleDisplayOrder();
      _round = _generator.nextRound();
      _clearAnswer();
      _selectedCompanyIndex = 0;
      _lastScore = null;
      _calculatorVisible = false;
      _phase = _CaseMathPhase.guess;
      _highScores = const [];
      _highlightHighScoreIndex = null;
    });
  }

  void _appendAnswer(String key) {
    if (key == '.' && _answerText.contains('.')) return;
    if (_answerText.length >= 16) return;
    setState(() {
      _parseError = null;
      _setAnswerText('$_answerText$key');
    });
  }

  void _backspaceAnswer() {
    if (_answerText.isEmpty) return;
    setState(() {
      _parseError = null;
      _setAnswerText(_answerText.substring(0, _answerText.length - 1));
    });
  }

  void _setInputMode(_InputMode mode) {
    setState(() => _inputMode = mode);
    if (mode == _InputMode.system) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _systemAnswerFocus.requestFocus();
      });
    } else {
      _systemAnswerFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _phase == _CaseMathPhase.summary
            ? _buildSummary(context)
            : _buildPlay(context),
      ),
    );
  }

  Widget _buildPlay(BuildContext context) {
    final roundLabel = 'Round ${_roundIndex + 1}/${widget.roundsPerSession}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  'Case Math · $roundLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showCaseMathFormulasModal(
                  context,
                  definition: case1Definition,
                ),
                child: const Text('Formulas'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${case1Definition.subtitle} · Score $_sessionScore',
            style: TextStyle(
              fontSize: 12,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  _CompanyTableSwitcher(
                    companies: _round.table.companies,
                    selectedIndex: _selectedCompanyIndex,
                    onChanged: (index) =>
                        setState(() => _selectedCompanyIndex = index),
                  ),
                  const SizedBox(height: AppUiSizes.sm),
                  CaseMathTable(
                    table: _round.table,
                    companyIndex: _selectedCompanyIndex,
                    highlights: _phase == _CaseMathPhase.reveal &&
                            _round.table.companies[_selectedCompanyIndex].id ==
                                _round.question.companyId
                        ? _round.answer.highlights
                        : const [],
                    onCellTap: _phase == _CaseMathPhase.reveal
                        ? _insertCalculatorValue
                        : null,
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Text(
                    _round.question.prompt,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  // Room so the floating calc does not cover the prompt.
                  if (_phase == _CaseMathPhase.reveal && _calculatorVisible)
                    const SizedBox(height: 220),
                ],
              ),
              if (_phase == _CaseMathPhase.reveal && _calculatorVisible)
                Positioned(
                  right: 16,
                  bottom: 8,
                  child: CaseMathCalculator(
                    key: _calculatorKey,
                    width: 220,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _phase == _CaseMathPhase.guess
              ? _buildGuessControls()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CaseMathCalculatorPanel(
                      visible: _calculatorVisible,
                      calculatorKey: _calculatorKey,
                      onVisibilityChanged: (visible) =>
                          setState(() => _calculatorVisible = visible),
                    ),
                    const SizedBox(height: AppUiSizes.sm),
                    _RevealCard(
                      score: _lastScore!,
                      answer: _round.answer,
                      onHighlightTap: _showQuestionCompany,
                    ),
                    const SizedBox(height: AppUiSizes.md),
                    _buildAdvanceButton(),
                  ],
                ),
        ),
      ],
    );
  }

  void _insertCalculatorValue(double value) {
    if (!_calculatorVisible) {
      setState(() => _calculatorVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculatorKey.currentState?.insertValue(value);
      });
      return;
    }
    _calculatorKey.currentState?.insertValue(value);
  }

  Widget _buildAdvanceButton() {
    final label = _roundIndex + 1 >= widget.roundsPerSession
        ? 'See summary'
        : 'Next';
    final button = PrimaryActionButton(text: label, onPressed: _next);

    // Match Check placement/width for the active input mode.
    return switch (_inputMode) {
      _InputMode.pad => button,
      _InputMode.mini => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(width: _caseMathMiniActionWidth, child: button),
      ),
      _InputMode.system => Align(
        alignment: Alignment.centerRight,
        child: button,
      ),
    };
  }

  Widget _buildGuessControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRectChipGroup<_InputMode>(
          value: _inputMode,
          size: SettingsRectChipSize.compact,
          spacing: 6,
          alignment: WrapAlignment.end,
          options: const [
            SettingsRectChipOption(
              value: _InputMode.system,
              label: 'System',
              icon: Icons.keyboard_outlined,
            ),
            SettingsRectChipOption(
              value: _InputMode.pad,
              label: 'Pad',
              icon: Icons.dialpad_outlined,
            ),
            SettingsRectChipOption(
              value: _InputMode.mini,
              label: 'Mini',
              icon: Icons.grid_view_outlined,
            ),
          ],
          onChanged: _setInputMode,
        ),
        const SizedBox(height: AppUiSizes.sm),
        if (_inputMode == _InputMode.system) ...[
          TextField(
            controller: _systemAnswerController,
            focusNode: _systemAnswerFocus,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            decoration: InputDecoration(
              hintText: _round.answer.type == CaseMathValueFormat.percentage
                  ? 'e.g. 18.7'
                  : 'e.g. 4462719',
              errorText: _parseError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (value) => setState(() {
              _parseError = null;
              _answerText = value;
            }),
            onSubmitted: (_) => _checkAnswer(),
          ),
          const SizedBox(height: AppUiSizes.sm),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryActionButton(
              text: 'Check',
              icon: Icons.check,
              onPressed: _checkAnswer,
            ),
          ),
        ] else ...[
          _AnswerDisplay(
            value: _answerText,
            type: _round.answer.type,
            error: _parseError,
            compact: _inputMode == _InputMode.mini,
          ),
          const SizedBox(height: AppUiSizes.sm),
          if (_inputMode == _InputMode.pad)
            CaseMathDigitPad(
              onKeyTap: _appendAnswer,
              onBackspace: _backspaceAnswer,
              onAction: _checkAnswer,
              actionLabel: 'Check answer',
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _caseMathMiniActionWidth,
                child: CaseMathDigitPad(
                  compact: true,
                  onKeyTap: _appendAnswer,
                  onBackspace: _backspaceAnswer,
                  onAction: _checkAnswer,
                  actionLabel: 'Check',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final board = _highScores
        .map((e) => RetroScoreEntry(score: e.score, at: e.at))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Session complete',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Score $_sessionScore · ${widget.roundsPerSession} rounds',
            style: TextStyle(color: AppColorPalette.textSecondary),
          ),
          const SizedBox(height: AppUiSizes.xl),
          RetroScoreboard(
            entries: board,
            highlightIndex: _highlightHighScoreIndex,
          ),
          const Spacer(),
          PrimaryActionButton(text: 'Play again', onPressed: _restart),
          const SizedBox(height: AppUiSizes.sm),
          SecondaryActionButton(
            text: widget.exitLabel,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CompanyTableSwitcher extends StatelessWidget {
  const _CompanyTableSwitcher({
    required this.companies,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<CaseMathCompanyData> companies;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) return const SizedBox.shrink();
    return SettingsRectChipGroup<int>(
      // title: 'Tables',
      titlePadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      value: selectedIndex,
      size: SettingsRectChipSize.compact,
      activeColor: AppColorPalette.color4,
      spacing: 8,
      options: [
        for (var i = 0; i < companies.length; i++)
          SettingsRectChipOption(
            value: i,
            label: '${companies[i].name} (${companies[i].id})',
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _AnswerDisplay extends StatelessWidget {
  const _AnswerDisplay({
    required this.value,
    required this.type,
    required this.error,
    this.compact = false,
  });

  final String value;
  final CaseMathValueFormat type;
  final String? error;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final suffix = type == CaseMathValueFormat.percentage ? '%' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: BoxConstraints(minHeight: compact ? 40 : 52),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: error == null
                    ? Colors.black.withValues(alpha: 0.55)
                    : AppColorPalette.error,
                width: error == null ? 1 : 1.5,
              ),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 130),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: 0.72, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$value$suffix',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: value.isEmpty
                    ? (compact ? 14.0 : 16.0)
                    : (compact ? 22.0 : 28.0),
                fontWeight: value.isEmpty ? FontWeight.w500 : FontWeight.w800,
                letterSpacing: value.isEmpty ? 0 : 1.2,
                color: value.isEmpty
                    ? AppColorPalette.textSecondary
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColorPalette.error),
            ),
          ),
      ],
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.score,
    required this.answer,
    required this.onHighlightTap,
  });

  final CaseMathScoreResult score;
  final CaseMathWorkedAnswer answer;
  final VoidCallback onHighlightTap;

  static Color _paletteColor(int index) {
    return switch (index % 5) {
      0 => AppColorPalette.color1,
      1 => AppColorPalette.color2,
      2 => AppColorPalette.color3,
      3 => AppColorPalette.color4,
      _ => AppColorPalette.color5,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ok = score.correct;
    final color = ok ? AppColorPalette.success : AppColorPalette.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok ? 'Correct · +${score.points}' : 'Not quite · +0',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            'Your answer: ${CaseMathScoring.formatValue(score.guess, answer.type)}',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'Exact: ${CaseMathScoring.formatValue(score.exact, answer.type)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _ColoredFormulaText(
            formula: answer.formula,
            highlights: answer.highlights,
            onHighlightTap: onHighlightTap,
          ),
          const SizedBox(height: 4),
          _ColoredSolutionText(
            parts: answer.solutionParts.isEmpty
                ? [CaseMathSolutionPart(text: answer.solution)]
                : answer.solutionParts,
            onHighlightTap: onHighlightTap,
            colorFor: _paletteColor,
          ),
        ],
      ),
    );
  }
}

class _ColoredFormulaText extends StatelessWidget {
  const _ColoredFormulaText({
    required this.formula,
    required this.highlights,
    required this.onHighlightTap,
  });

  final String formula;
  final List<CaseMathFormulaHighlight> highlights;
  final VoidCallback onHighlightTap;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Text(
        formula,
        style: TextStyle(fontSize: 12, color: AppColorPalette.textSecondary),
      );
    }

    // Prefer one color per metric name (primary-year binding first).
    final byName = <String, CaseMathFormulaHighlight>{};
    for (final highlight in highlights) {
      byName.putIfAbsent(highlight.metricName, () => highlight);
    }
    final names = byName.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final spans = <InlineSpan>[];
    var remaining = formula;
    while (remaining.isNotEmpty) {
      Match? best;
      CaseMathFormulaHighlight? bestHighlight;
      for (final name in names) {
        final match = RegExp(RegExp.escape(name)).firstMatch(remaining);
        if (match == null) continue;
        if (best == null || match.start < best.start) {
          best = match;
          bestHighlight = byName[name];
        }
      }
      if (best == null || bestHighlight == null) {
        spans.add(TextSpan(text: remaining));
        break;
      }
      if (best.start > 0) {
        spans.add(TextSpan(text: remaining.substring(0, best.start)));
      }
      final color = _RevealCard._paletteColor(bestHighlight.colorIndex);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onHighlightTap,
            child: Text(
              bestHighlight.metricName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
      remaining = remaining.substring(best.end);
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12, color: AppColorPalette.textSecondary),
        children: spans,
      ),
    );
  }
}

class _ColoredSolutionText extends StatelessWidget {
  const _ColoredSolutionText({
    required this.parts,
    required this.onHighlightTap,
    required this.colorFor,
  });

  final List<CaseMathSolutionPart> parts;
  final VoidCallback onHighlightTap;
  final Color Function(int index) colorFor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.35),
        children: [
          for (final part in parts)
            if (part.highlight == null)
              TextSpan(text: part.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onHighlightTap,
                  child: Text(
                    part.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorFor(part.highlight!.colorIndex),
                      decoration: TextDecoration.underline,
                      decorationColor: colorFor(
                        part.highlight!.colorIndex,
                      ).withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CaseMathHighScore {
  const _CaseMathHighScore({required this.score, required this.at});

  final int score;
  final DateTime at;

  Map<String, dynamic> toMap() => {
    'score': score,
    'atMs': at.millisecondsSinceEpoch,
  };

  static _CaseMathHighScore? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final atMs = raw['atMs'];
    if (score is! num || atMs is! num) return null;
    return _CaseMathHighScore(
      score: score.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(atMs.toInt()),
    );
  }
}

class _CaseMathHighScoreRecordResult {
  const _CaseMathHighScoreRecordResult({
    required this.board,
    required this.insertedIndex,
  });

  final List<_CaseMathHighScore> board;
  final int? insertedIndex;
}

class _CaseMathHighScores {
  static const _boxName = 'app_init_flags';
  static const _maxEntries = 10;

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<List<_CaseMathHighScore>> load(String storageKey) async {
    final box = await _box();
    final raw = box.get(storageKey);
    if (raw is! List) return const [];
    return raw
        .map(_CaseMathHighScore.fromMap)
        .whereType<_CaseMathHighScore>()
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.at.compareTo(a.at);
      });
  }

  static Future<_CaseMathHighScoreRecordResult> record({
    required int score,
    required DateTime at,
    required String storageKey,
  }) async {
    final entry = _CaseMathHighScore(score: score, at: at);
    final board = [...await load(storageKey), entry]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.at.compareTo(a.at);
      });
    final trimmed = board.take(_maxEntries).toList();
    final insertedIndex = trimmed.indexWhere(
      (e) =>
          e.score == entry.score &&
          e.at.millisecondsSinceEpoch == entry.at.millisecondsSinceEpoch,
    );
    final box = await _box();
    await box.put(storageKey, trimmed.map((e) => e.toMap()).toList());
    return _CaseMathHighScoreRecordResult(
      board: trimmed,
      insertedIndex: insertedIndex >= 0 ? insertedIndex : null,
    );
  }
}

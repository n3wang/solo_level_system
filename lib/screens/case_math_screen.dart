import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case1_definition.dart';
import 'package:solo_level_system/utils/case_math/case2_definition.dart';
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

enum _CaseMathPhase { pickCase, guess, reveal, calculatorRecap, summary }

enum _InputMode { system, pad, mini }

class _CaseMathRoundResult {
  const _CaseMathRoundResult({
    required this.prompt,
    required this.guess,
    required this.exact,
    required this.type,
    required this.points,
  });

  final String prompt;
  final double guess;
  final double exact;
  final CaseMathValueFormat type;
  final int points;
}

class _RecallFeedback {
  const _RecallFeedback({
    required this.correct,
    required this.expression,
    required this.guess,
    required this.exact,
    this.points = 0,
  });

  final bool correct;
  final String expression;
  final double guess;
  final double exact;
  final int points;
}

/// Fixed mini keypad / Check / Next width so reveal does not jump.
const double _caseMathMiniActionWidth = 168;

/// Case Math mini-game with selectable case definitions.
class CaseMathScreen extends StatefulWidget {
  const CaseMathScreen({
    super.key,
    this.roundsPerSession = 5,
    this.exitLabel = 'Back to games',
    this.definition,
    this.availableCases = const [case1Definition, case2Definition],
  });

  final int roundsPerSession;
  final String exitLabel;

  /// When set, skips the case picker and starts this case immediately.
  final CaseMathCaseDefinition? definition;

  /// Cases shown on the picker when [definition] is null.
  final List<CaseMathCaseDefinition> availableCases;

  /// Catalog / hub identity (not per-case high-score storage).
  static const highScoreKey = 'case_math_high_scores';

  static String storageKeyFor(CaseMathCaseDefinition definition) =>
      definition.highScoreKey ?? highScoreKey;

  @override
  State<CaseMathScreen> createState() => _CaseMathScreenState();
}

class _CaseMathScreenState extends State<CaseMathScreen> {
  final _systemAnswerController = TextEditingController();
  final _systemAnswerFocus = FocusNode();
  final _keyboardFocus = FocusNode();
  final _calculatorKey = GlobalKey<CaseMathCalculatorState>();

  CaseMathCaseDefinition? _definition;
  CaseMathGenerator? _generator;
  CaseMathRound? _round;
  late _CaseMathPhase _phase;
  int _roundIndex = 0;
  int _sessionScore = 0;
  int _selectedViewIndex = 0;
  int _selectedEntityIndex = 0;
  _InputMode _inputMode = _InputMode.mini;
  bool _calculatorVisible = false;
  int _calculatorDigitsUsed = 0;
  String _answerText = '';
  CaseMathScoreResult? _lastScore;
  String? _parseError;

  List<_CaseMathHighScore> _highScores = const [];
  int? _highlightHighScoreIndex;
  final List<_CaseMathRoundResult> _roundResults = [];
  final List<CaseMathComputation> _sessionComputations = [];
  final List<CaseMathComputation> _recallQueue = [];
  int _recallInitialCount = 0;
  int _recallBonusEarned = 0;
  bool _recallCompleted = false;
  _RecallFeedback? _recallFeedback;

  /// Summary reveal: round rows → recall bonus → total → scoreboard.
  int _summaryVisibleRows = 0;
  bool _summaryShowRecall = false;
  bool _summaryShowTotal = false;
  bool _summaryShowBoard = false;
  int _summaryAnimToken = 0;

  CaseMathCaseDefinition get _case => _definition!;
  CaseMathGenerator get _gen => _generator!;
  CaseMathRound get _current => _round!;

  String get _storageKey => CaseMathScreen.storageKeyFor(_case);

  bool get _isAnsweringPhase =>
      _phase == _CaseMathPhase.guess || _phase == _CaseMathPhase.calculatorRecap;

  bool get _capturesHardwareKeys {
    if (_calculatorVisible) return true;
    if (_isAnsweringPhase) {
      return _inputMode == _InputMode.pad || _inputMode == _InputMode.mini;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.definition;
    if (initial != null) {
      _phase = _CaseMathPhase.guess;
      _beginCase(initial, resetSession: true);
    } else {
      _phase = _CaseMathPhase.pickCase;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  void _beginCase(CaseMathCaseDefinition definition, {required bool resetSession}) {
    _definition = definition;
    _generator = CaseMathGenerator(definition: definition);
    _round = _generator!.nextRound();
    _selectedViewIndex = _defaultViewIndex(_round!);
    _selectedEntityIndex = _focusEntityIndex(_round!);
    if (resetSession) {
      _roundIndex = 0;
      _sessionScore = 0;
      _lastScore = null;
      _calculatorVisible = false;
      _calculatorDigitsUsed = 0;
      _roundResults.clear();
      _sessionComputations.clear();
      _recallQueue.clear();
      _recallInitialCount = 0;
      _recallBonusEarned = 0;
      _recallCompleted = false;
      _recallFeedback = null;
      _highScores = const [];
      _highlightHighScoreIndex = null;
      _clearAnswer();
    }
  }

  int _defaultViewIndex(CaseMathRound round) {
    final focusId = round.question.focusTableId;
    if (focusId != null) {
      final index =
          round.table.views.indexWhere((view) => view.definition.id == focusId);
      if (index >= 0) return index;
    }
    return 0;
  }

  int _focusEntityIndex(CaseMathRound round) {
    final viewIndex = _defaultViewIndex(round);
    final view = round.table.views[viewIndex];
    final index = view.entities.indexWhere(
      (entity) => entity.id == round.question.companyId,
    );
    return index >= 0 ? index : 0;
  }

  @override
  void dispose() {
    _systemAnswerController.dispose();
    _systemAnswerFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _syncKeyboardFocus() {
    if (!mounted) return;
    if (_capturesHardwareKeys) {
      _systemAnswerFocus.unfocus();
      _keyboardFocus.requestFocus();
    } else if (_inputMode == _InputMode.system && _isAnsweringPhase) {
      _keyboardFocus.unfocus();
    }
  }

  void _setAnswerText(String value) {
    final stripped = value.replaceAll(',', '');
    _answerText = stripped;
    final formatted = CaseMathScoring.withThousandSeparators(stripped);
    if (_systemAnswerController.text != formatted) {
      _systemAnswerController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  /// Keeps at most one leading minus; strips other sign characters.
  String _normalizeSignedInput(String value) {
    final stripped = value.replaceAll(',', '').replaceAll('−', '-');
    final negative = stripped.contains('-');
    final body = stripped.replaceAll('-', '');
    if (!negative) return body;
    return '-$body';
  }

  void _clearAnswer() {
    _setAnswerText('');
    _parseError = null;
  }

  Future<void> _checkAnswer() async {
    if (_phase == _CaseMathPhase.calculatorRecap) {
      _checkRecallAnswer();
      return;
    }
    final parsed = CaseMathScoring.parseGuess(_answerText);
    if (parsed == null) {
      setState(() => _parseError = 'Enter a number');
      return;
    }
    final result = CaseMathScoring.score(
      guess: parsed,
      answer: _current.answer,
      calculatorDigitsUsed: _calculatorDigitsUsed,
    );
    setState(() {
      _parseError = null;
      _lastScore = result;
      _sessionScore += result.points;
      _phase = _CaseMathPhase.reveal;
      _calculatorVisible = false;
      _selectedViewIndex = _defaultViewIndex(_current);
      _selectedEntityIndex = _focusEntityIndex(_current);
      _roundResults.add(
        _CaseMathRoundResult(
          prompt: _current.question.prompt,
          guess: result.guess,
          exact: result.exact,
          type: _current.answer.type,
          points: result.points,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  void _onCalculatorComputation(CaseMathComputation computation) {
    CaseMathScoring.recordUniqueComputation(
      _sessionComputations,
      computation,
    );
  }

  void _checkRecallAnswer() {
    if (_recallQueue.isEmpty) {
      unawaited(_enterSummary());
      return;
    }
    final parsed = CaseMathScoring.parseGuess(_answerText);
    if (parsed == null) {
      setState(() => _parseError = 'Enter a number');
      return;
    }
    final current = _recallQueue.first;
    final correct = CaseMathScoring.isRecallCorrect(
      guess: parsed,
      exact: current.result,
    );
    setState(() {
      _parseError = null;
      CaseMathScoring.advanceRecallQueue(
        queue: _recallQueue,
        correct: correct,
      );
      if (correct) {
        _sessionScore += CaseMathScoring.recallRewardPoints;
        _recallBonusEarned += CaseMathScoring.recallRewardPoints;
      }
      _recallFeedback = _RecallFeedback(
        correct: correct,
        expression: current.expression,
        guess: parsed,
        exact: current.result,
        points: correct ? CaseMathScoring.recallRewardPoints : 0,
      );
      _clearAnswer();
    });
    if (_recallQueue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted || _phase != _CaseMathPhase.calculatorRecap) return;
        await _enterSummary(recallCompleted: true);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  Future<void> _enterCalculatorRecap() async {
    _calculatorKey.currentState?.resetForNewQuestion();
    setState(() {
      _recallQueue
        ..clear()
        ..addAll(_sessionComputations);
      _recallInitialCount = _recallQueue.length;
      _recallBonusEarned = 0;
      _recallCompleted = false;
      _recallFeedback = null;
      _calculatorVisible = false;
      _calculatorDigitsUsed = 0;
      _clearAnswer();
      _phase = _CaseMathPhase.calculatorRecap;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  Future<void> _skipCalculatorRecap() async {
    await _enterSummary(recallCompleted: false);
  }

  void _showQuestionSource([CaseMathFormulaHighlight? highlight]) {
    final round = _current;
    final tableId = highlight?.tableId ??
        round.question.focusTableId ??
        round.table.primaryView.definition.id;
    final viewIndex =
        round.table.views.indexWhere((view) => view.definition.id == tableId);
    if (viewIndex < 0) return;
    final view = round.table.views[viewIndex];
    final entityId = highlight?.entityId ?? round.question.companyId;
    final entityIndex = view.entities.indexWhere((entity) => entity.id == entityId);
    setState(() {
      _selectedViewIndex = viewIndex;
      if (entityIndex >= 0) _selectedEntityIndex = entityIndex;
    });
  }

  Future<void> _next() async {
    if (_roundIndex + 1 >= widget.roundsPerSession) {
      if (_sessionComputations.isNotEmpty) {
        await _enterCalculatorRecap();
      } else {
        await _enterSummary();
      }
      return;
    }
    _calculatorKey.currentState?.resetForNewQuestion();
    setState(() {
      _roundIndex += 1;
      _round = _gen.nextRound();
      _clearAnswer();
      _selectedViewIndex = _defaultViewIndex(_current);
      _selectedEntityIndex = _focusEntityIndex(_current);
      _lastScore = null;
      _calculatorVisible = false;
      _calculatorDigitsUsed = 0;
      _phase = _CaseMathPhase.guess;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  Future<void> _enterSummary({bool recallCompleted = false}) async {
    final recorded = await _CaseMathHighScores.record(
      score: _sessionScore,
      at: DateTime.now(),
      storageKey: _storageKey,
    );
    if (!mounted) return;
    setState(() {
      _phase = _CaseMathPhase.summary;
      _recallCompleted = recallCompleted;
      _highScores = recorded.board;
      _highlightHighScoreIndex = recorded.insertedIndex;
      _summaryVisibleRows = 0;
      _summaryShowRecall = false;
      _summaryShowTotal = false;
      _summaryShowBoard = false;
    });
    unawaited(_runSummaryReveal());
  }

  Future<void> _runSummaryReveal() async {
    final token = ++_summaryAnimToken;
    const step = Duration(milliseconds: 200);

    for (var i = 0; i < _roundResults.length; i++) {
      await Future<void>.delayed(step);
      if (!mounted || token != _summaryAnimToken) return;
      if (_phase != _CaseMathPhase.summary) return;
      setState(() => _summaryVisibleRows = i + 1);
    }

    if (_recallCompleted) {
      await Future<void>.delayed(step);
      if (!mounted || token != _summaryAnimToken) return;
      if (_phase != _CaseMathPhase.summary) return;
      setState(() => _summaryShowRecall = true);
    }

    await Future<void>.delayed(step);
    if (!mounted || token != _summaryAnimToken) return;
    if (_phase != _CaseMathPhase.summary) return;
    setState(() => _summaryShowTotal = true);

    await Future<void>.delayed(step);
    if (!mounted || token != _summaryAnimToken) return;
    if (_phase != _CaseMathPhase.summary) return;
    setState(() => _summaryShowBoard = true);
  }

  void _restart() {
    _calculatorKey.currentState?.resetForNewQuestion();
    if (widget.definition == null) {
      setState(() {
        _definition = null;
        _generator = null;
        _round = null;
        _phase = _CaseMathPhase.pickCase;
        _roundIndex = 0;
        _sessionScore = 0;
        _clearAnswer();
        _lastScore = null;
        _calculatorVisible = false;
        _calculatorDigitsUsed = 0;
        _highScores = const [];
        _highlightHighScoreIndex = null;
        _roundResults.clear();
        _sessionComputations.clear();
        _recallQueue.clear();
        _recallInitialCount = 0;
        _recallBonusEarned = 0;
        _recallCompleted = false;
        _recallFeedback = null;
        _summaryVisibleRows = 0;
        _summaryShowRecall = false;
        _summaryShowTotal = false;
        _summaryShowBoard = false;
        _summaryAnimToken++;
      });
      return;
    }
    setState(() {
      _beginCase(widget.definition!, resetSession: true);
      _phase = _CaseMathPhase.guess;
      _summaryVisibleRows = 0;
      _summaryShowRecall = false;
      _summaryShowTotal = false;
      _summaryShowBoard = false;
      _summaryAnimToken++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  void _pickCase(CaseMathCaseDefinition definition) {
    setState(() {
      _beginCase(definition, resetSession: true);
      _phase = _CaseMathPhase.guess;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
  }

  void _appendAnswer(String key) {
    if (key == '.' && _answerText.contains('.')) return;
    if (key == '-') {
      _toggleAnswerSign();
      return;
    }
    if (_answerText.length >= 16) return;
    setState(() {
      _parseError = null;
      _setAnswerText('$_answerText$key');
    });
  }

  void _toggleAnswerSign() {
    setState(() {
      _parseError = null;
      if (_answerText.startsWith('-')) {
        _setAnswerText(_answerText.substring(1));
      } else {
        _setAnswerText('-$_answerText');
      }
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncKeyboardFocus());
    }
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (!_capturesHardwareKeys) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_calculatorVisible) {
      final handled =
          _calculatorKey.currentState?.handleHardwareKey(event) ?? false;
      return handled ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (!_isAnsweringPhase) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspaceAnswer();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _checkAnswer();
      return KeyEventResult.handled;
    }

    final token = _guessTokenForHardwareKey(event);
    if (token == null) return KeyEventResult.ignored;
    _appendAnswer(token);
    return KeyEventResult.handled;
  }

  String? _guessTokenForHardwareKey(KeyEvent event) {
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      if (RegExp(r'^[0-9]$').hasMatch(character)) return character;
      if (character == '.') return '.';
      if (character == '-' || character == '−') return '-';
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.period) {
      return '.';
    }
    if (key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.minus) {
      return '-';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: switch (_phase) {
          _CaseMathPhase.pickCase => _buildCasePicker(context),
          _CaseMathPhase.summary => _buildSummary(context),
          _CaseMathPhase.calculatorRecap => Focus(
              focusNode: _keyboardFocus,
              onKeyEvent: _onHardwareKey,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (_capturesHardwareKeys) _syncKeyboardFocus();
                },
                child: _buildCalculatorRecap(context),
              ),
            ),
          _ => Focus(
              focusNode: _keyboardFocus,
              onKeyEvent: _onHardwareKey,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (_capturesHardwareKeys) _syncKeyboardFocus();
                },
                child: _buildPlay(context),
              ),
            ),
        },
      ),
    );
  }

  Widget _buildCasePicker(BuildContext context) {
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
              const Expanded(
                child: Text(
                  'Case Math',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Choose a case',
            style: TextStyle(
              fontSize: 13,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: widget.availableCases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final definition = widget.availableCases[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  onTap: () => _pickCase(definition),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.55),
                        width: AppUiSizes.smallBorderWidth,
                      ),
                      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          definition.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColorPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${definition.tables.length} tables · ${definition.questions.length} question types',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColorPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlay(BuildContext context) {
    final round = _current;
    final views = round.table.views;
    final selectedView = views[_selectedViewIndex.clamp(0, views.length - 1)];
    final showEntitySwitcher =
        selectedView.definition.kind == CaseMathTableKind.companyYears &&
            selectedView.entities.length > 1;
    final highlights = _phase == _CaseMathPhase.reveal
        ? round.answer.highlights
            .where(
              (h) => (h.tableId ?? selectedView.definition.id) ==
                  selectedView.definition.id,
            )
            .toList()
        : const <CaseMathFormulaHighlight>[];
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
                  '${_case.title} · $roundLabel',
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
                  definition: _case,
                ),
                child: const Text('Formulas'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${_case.subtitle} · Score $_sessionScore',
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
                  if (views.length > 1) ...[
                    _TableViewSwitcher(
                      views: views,
                      selectedIndex: _selectedViewIndex,
                      onChanged: (index) =>
                          setState(() => _selectedViewIndex = index),
                    ),
                    const SizedBox(height: AppUiSizes.sm),
                  ],
                  if (showEntitySwitcher) ...[
                    _CompanyTableSwitcher(
                      companies: selectedView.entities,
                      selectedIndex: _selectedEntityIndex.clamp(
                        0,
                        selectedView.entities.length - 1,
                      ),
                      onChanged: (index) =>
                          setState(() => _selectedEntityIndex = index),
                    ),
                    const SizedBox(height: AppUiSizes.sm),
                  ],
                  CaseMathTable(
                    view: selectedView,
                    entityIndex: _selectedEntityIndex,
                    highlights: highlights,
                    onCellTap: _phase == _CaseMathPhase.reveal
                        ? _insertCalculatorValue
                        : null,
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Text(
                    round.question.prompt,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  // Room so the floating calc does not cover the prompt.
                  if (_calculatorVisible) const SizedBox(height: 240),
                ],
              ),
              if (_calculatorVisible)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: CaseMathCalculator(
                    key: _calculatorKey,
                    width: 200,
                    historyWidth: 92,
                    onDigitEntered: _phase == _CaseMathPhase.guess
                        ? _onCalculatorDigitEntered
                        : null,
                    onComputation: _onCalculatorComputation,
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
                    _buildCalculatorToggle(),
                    const SizedBox(height: AppUiSizes.sm),
                    _RevealCard(
                      score: _lastScore!,
                      answer: round.answer,
                      onHighlightTap: _showQuestionSource,
                    ),
                    const SizedBox(height: AppUiSizes.md),
                    _buildAdvanceButton(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCalculatorRecap(BuildContext context) {
    final remaining = _recallQueue.length;
    final current = _recallQueue.isEmpty ? null : _recallQueue.first;
    final solved = _recallInitialCount - remaining;
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
              const Expanded(
                child: Text(
                  'Calculator recall',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: _skipCalculatorRecap,
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Recall each calc result (±3% or ±0.05) · Score $_sessionScore'
            '${_recallBonusEarned > 0 ? ' · +$_recallBonusEarned recall' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              Text(
                remaining == 0
                    ? 'All recalled'
                    : 'Left $remaining · Done $solved/$_recallInitialCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppUiSizes.md),
              if (current != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What was the result?',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColorPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${CaseMathScoring.withThousandSeparatorsInExpression(current.expression)} = ?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_recallFeedback != null) ...[
                const SizedBox(height: AppUiSizes.md),
                _buildRecallFeedbackCard(_recallFeedback!),
              ],
            ],
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildAnswerEntryControls(
              hintText: 'e.g. 1,234.5',
              showPercentageSuffix: false,
              onCheck: _checkRecallAnswer,
            ),
          ),
      ],
    );
  }

  Widget _buildRecallFeedbackCard(_RecallFeedback feedback) {
    final color =
        feedback.correct ? AppColorPalette.success : AppColorPalette.error;
    final expression =
        CaseMathScoring.withThousandSeparatorsInExpression(feedback.expression);
    final exactText = CaseMathScoring.formatRecallNumber(feedback.exact);
    final guessDisplay = CaseMathScoring.formatRecallNumber(feedback.guess);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.correct
                ? 'Correct · +${feedback.points}'
                : 'Not quite · moved to end of queue',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$expression = $exactText',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your answer: $guessDisplay',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'Exact: $exactText',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _onCalculatorDigitEntered() {
    if (_phase != _CaseMathPhase.guess) return;
    setState(() => _calculatorDigitsUsed += 1);
  }

  Widget _buildCalculatorToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaseMathCalculatorPanel(
          visible: _calculatorVisible,
          calculatorKey: _calculatorKey,
          onVisibilityChanged: (visible) {
            setState(() => _calculatorVisible = visible);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _syncKeyboardFocus());
          },
        ),
        if (_phase == _CaseMathPhase.guess && _calculatorVisible)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _calculatorDigitsUsed == 0
                    ? '−${CaseMathScoring.calculatorDigitPenalty} pts / digit'
                    : '−${_calculatorDigitsUsed * CaseMathScoring.calculatorDigitPenalty} pts'
                        ' ($_calculatorDigitsUsed digits)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColorPalette.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _insertCalculatorValue(double value) {
    if (!_calculatorVisible) {
      setState(() => _calculatorVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncKeyboardFocus();
        _calculatorKey.currentState?.insertValue(value);
      });
      return;
    }
    _calculatorKey.currentState?.insertValue(value);
  }

  Widget _buildAdvanceButton() {
    final isLast = _roundIndex + 1 >= widget.roundsPerSession;
    final label = !isLast
        ? 'Next'
        : (_sessionComputations.isNotEmpty ? 'Continue' : 'See summary');
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
        _buildCalculatorToggle(),
        const SizedBox(height: AppUiSizes.sm),
        _buildAnswerEntryControls(
          hintText: _current.answer.type == CaseMathValueFormat.percentage
              ? 'e.g. -10.5'
              : 'e.g. 4,462,719',
          showPercentageSuffix:
              _current.answer.type == CaseMathValueFormat.percentage,
          onCheck: _checkAnswer,
        ),
      ],
    );
  }

  Widget _buildAnswerEntryControls({
    required String hintText,
    required bool showPercentageSuffix,
    required VoidCallback onCheck,
  }) {
    final displayType = showPercentageSuffix
        ? CaseMathValueFormat.percentage
        : CaseMathValueFormat.number;
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
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-,]')),
            ],
            decoration: InputDecoration(
              hintText: hintText,
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
              _setAnswerText(_normalizeSignedInput(value));
            }),
            onSubmitted: (_) => onCheck(),
          ),
          const SizedBox(height: AppUiSizes.sm),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryActionButton(
              text: 'Check',
              icon: Icons.check,
              onPressed: onCheck,
            ),
          ),
        ] else ...[
          _AnswerDisplay(
            value: CaseMathScoring.withThousandSeparators(_answerText),
            type: displayType,
            error: _parseError,
            compact: _inputMode == _InputMode.mini,
          ),
          const SizedBox(height: AppUiSizes.sm),
          if (_inputMode == _InputMode.pad)
            CaseMathDigitPad(
              onKeyTap: _appendAnswer,
              onBackspace: _backspaceAnswer,
              onToggleSign: _toggleAnswerSign,
              onAction: onCheck,
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
                  onToggleSign: _toggleAnswerSign,
                  onAction: onCheck,
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
          const Text(
            'Session complete',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _recallBonusEarned > 0
                ? '${widget.roundsPerSession} rounds · +$_recallBonusEarned recall'
                : '${widget.roundsPerSession} rounds',
            style: TextStyle(
              fontSize: 13,
              color: AppColorPalette.textSecondary,
            ),
          ),
          const SizedBox(height: AppUiSizes.md),
          Expanded(
            child: ListView(
              children: [
                if (_summaryVisibleRows > 0)
                  _SummaryReveal(child: _buildSummaryHeader()),
                for (var i = 0; i < _summaryVisibleRows; i++)
                  _SummaryReveal(child: _buildSummaryRoundRow(i)),
                if (_summaryShowRecall)
                  _SummaryReveal(child: _buildSummaryRecallRow()),
                if (_summaryShowTotal) ...[
                  const Divider(height: 24),
                  _SummaryReveal(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$_sessionScore',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_summaryShowBoard) ...[
                  const SizedBox(height: 20),
                  _SummaryReveal(
                    child: RetroScoreboard(
                      entries: board,
                      highlightIndex: _highlightHighScoreIndex,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
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

  Widget _buildSummaryHeader() {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColorPalette.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#', style: style)),
          Expanded(flex: 3, child: Text('Question', style: style)),
          Expanded(child: Text('Yours', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Exact', style: style, textAlign: TextAlign.right)),
          SizedBox(
            width: 52,
            child: Text('Pts', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRecallRow() {
    final pointsText =
        _recallBonusEarned > 0 ? '+$_recallBonusEarned' : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 28,
            child: Text(
              '★',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Calculator recall',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
          const Expanded(
            child: Text(
              '—',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              '$_recallInitialCount done',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              pointsText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRoundRow(int index) {
    final round = _roundResults[index];
    final guessText = CaseMathScoring.formatValue(round.guess, round.type);
    final exactText = CaseMathScoring.formatValue(round.exact, round.type);
    final pointsText = round.points > 0 ? '+${round.points}' : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              round.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
          Expanded(
            child: Text(
              guessText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: round.points > 0
                    ? AppColorPalette.success
                    : AppColorPalette.error,
              ),
            ),
          ),
          Expanded(
            child: Text(
              exactText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              pointsText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short fade + rise used by the Case Math summary stagger.
class _SummaryReveal extends StatelessWidget {
  const _SummaryReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _TableViewSwitcher extends StatelessWidget {
  const _TableViewSwitcher({
    required this.views,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<CaseMathTableView> views;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (views.length <= 1) return const SizedBox.shrink();
    return SettingsRectChipGroup<int>(
      titlePadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      value: selectedIndex,
      size: SettingsRectChipSize.compact,
      activeColor: AppColorPalette.color4,
      spacing: 8,
      options: [
        for (var i = 0; i < views.length; i++)
          SettingsRectChipOption(
            value: i,
            label: views[i].definition.title,
          ),
      ],
      onChanged: onChanged,
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
            label: companies[i].name,
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
  final void Function([CaseMathFormulaHighlight? highlight]) onHighlightTap;

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
            ok
                ? (score.calculatorPenalty > 0
                    ? 'Correct · +${score.points} (−${score.calculatorPenalty} calc)'
                    : 'Correct · +${score.points}')
                : 'Not quite · +0',
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
  final void Function([CaseMathFormulaHighlight? highlight]) onHighlightTap;

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
            onTap: () => onHighlightTap(bestHighlight),
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
  final void Function([CaseMathFormulaHighlight? highlight]) onHighlightTap;
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
                  onTap: () => onHighlightTap(part.highlight),
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

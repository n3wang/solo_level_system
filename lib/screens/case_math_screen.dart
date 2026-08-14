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
import 'package:solo_level_system/widgets/games/case_math_formulas_modal.dart';
import 'package:solo_level_system/widgets/games/case_math_table.dart';
import 'package:solo_level_system/widgets/games/retro_scoreboard.dart';

enum _CaseMathPhase { guess, reveal, summary }

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
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();

  late CaseMathRound _round;
  _CaseMathPhase _phase = _CaseMathPhase.guess;
  int _roundIndex = 0;
  int _sessionScore = 0;
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
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  Future<void> _checkAnswer() async {
    final parsed = CaseMathScoring.parseGuess(_answerController.text);
    if (parsed == null) {
      setState(() => _parseError = 'Enter a number');
      return;
    }
    final result = CaseMathScoring.score(guess: parsed, answer: _round.answer);
    setState(() {
      _parseError = null;
      _lastScore = result;
      _sessionScore += result.points;
      _phase = _CaseMathPhase.reveal;
    });
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
      _answerController.clear();
      _lastScore = null;
      _parseError = null;
      _phase = _CaseMathPhase.guess;
    });
    _answerFocus.requestFocus();
  }

  void _restart() {
    setState(() {
      _roundIndex = 0;
      _sessionScore = 0;
      _round = _generator.nextRound();
      _answerController.clear();
      _lastScore = null;
      _parseError = null;
      _phase = _CaseMathPhase.guess;
      _highScores = const [];
      _highlightHighScoreIndex = null;
    });
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
            'Coffee chain · Score $_sessionScore',
            style: TextStyle(
              fontSize: 12,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              CaseMathTable(table: _round.table),
              const SizedBox(height: AppUiSizes.lg),
              Text(
                _round.question.prompt,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppUiSizes.md),
              if (_phase == _CaseMathPhase.guess) ...[
                TextField(
                  controller: _answerController,
                  focusNode: _answerFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-−%$ ]')),
                  ],
                  decoration: InputDecoration(
                    hintText:
                        _round.answer.type == CaseMathValueFormat.percentage
                        ? 'e.g. 18.7 or 18.7%'
                        : 'e.g. 4462719 or 4,462,719',
                    errorText: _parseError,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppUiSizes.buttonRadius),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _checkAnswer(),
                ),
                const SizedBox(height: AppUiSizes.md),
                PrimaryActionButton(
                  text: 'Check',
                  onPressed: _checkAnswer,
                ),
              ] else ...[
                _RevealCard(
                  score: _lastScore!,
                  answer: _round.answer,
                ),
                const SizedBox(height: AppUiSizes.md),
                PrimaryActionButton(
                  text: _roundIndex + 1 >= widget.roundsPerSession
                      ? 'See summary'
                      : 'Next',
                  onPressed: _next,
                ),
              ],
            ],
          ),
        ),
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
          PrimaryActionButton(
            text: 'Play again',
            onPressed: _restart,
          ),
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

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.score, required this.answer});

  final CaseMathScoreResult score;
  final CaseMathWorkedAnswer answer;

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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
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
          Text(
            answer.formula,
            style: TextStyle(
              fontSize: 12,
              color: AppColorPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer.solution,
            style: const TextStyle(fontSize: 13, height: 1.35),
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

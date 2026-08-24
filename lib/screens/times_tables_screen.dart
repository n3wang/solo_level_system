import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/times_tables/times_tables_problems.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/games/case_math_keypad.dart';
import 'package:solo_level_system/widgets/games/retro_scoreboard.dart';

enum _TimesPhase { ready, countdown, racing, summary }

/// Timed multiplication-table race (facts without 1, 2, or 10).
class TimesTablesScreen extends StatefulWidget {
  const TimesTablesScreen({
    super.key,
    this.exitLabel = 'Back to games',
  });

  final String exitLabel;

  static const highScoreKey = 'times_tables_high_scores';
  static const durationKey = 'times_tables_duration_seconds';

  @override
  State<TimesTablesScreen> createState() => _TimesTablesScreenState();
}

class _TimesTablesScreenState extends State<TimesTablesScreen> {
  static const _durations = [30, 60, 90];
  static const _countdownSeconds = 3;

  final _keyboardFocus = FocusNode();
  final _random = Random();

  _TimesPhase _phase = _TimesPhase.ready;
  int _durationSeconds = 60;
  int _countdownLeft = _countdownSeconds;
  int _remainingMs = 60000;
  DateTime? _raceStartedAt;
  Timer? _ticker;

  TimesTableProblem _problem = const TimesTableProblem(3, 3);
  String _answerText = '';
  int _correct = 0;
  int _misses = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _sessionScore = 0;
  bool _flashWrong = false;

  List<_TimesHighScore> _highScores = const [];
  int? _highlightHighScoreIndex;
  int _summaryVisibleRows = 0;
  bool _summaryShowTotal = false;
  bool _summaryShowBoard = false;
  int _summaryAnimToken = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final box = await _TimesHighScores._box();
    final stored = box.get(TimesTablesScreen.durationKey);
    if (!mounted) return;
    setState(() {
      if (stored is num && _durations.contains(stored.toInt())) {
        _durationSeconds = stored.toInt();
      }
    });
  }

  Future<void> _setDuration(int seconds) async {
    setState(() => _durationSeconds = seconds);
    final box = await _TimesHighScores._box();
    await box.put(TimesTablesScreen.durationKey, seconds);
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() {
      _phase = _TimesPhase.countdown;
      _countdownLeft = _countdownSeconds;
      _correct = 0;
      _misses = 0;
      _streak = 0;
      _bestStreak = 0;
      _sessionScore = 0;
      _answerText = '';
      _flashWrong = false;
      _problem = TimesTablesProblems.next(_random);
      _remainingMs = _durationSeconds * 1000;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _TimesPhase.countdown) return;
      final next = _countdownLeft - 1;
      if (next <= 0) {
        _beginRace();
        return;
      }
      setState(() => _countdownLeft = next);
    });
  }

  void _beginRace() {
    _ticker?.cancel();
    _raceStartedAt = DateTime.now();
    setState(() {
      _phase = _TimesPhase.racing;
      _remainingMs = _durationSeconds * 1000;
    });
    _syncKeyboardFocus();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _phase != _TimesPhase.racing || _raceStartedAt == null) {
        return;
      }
      final elapsed = DateTime.now().difference(_raceStartedAt!).inMilliseconds;
      final left = (_durationSeconds * 1000) - elapsed;
      if (left <= 0) {
        _finishRace();
        return;
      }
      setState(() => _remainingMs = left);
    });
  }

  Future<void> _finishRace() async {
    _ticker?.cancel();
    final finishedAt = DateTime.now();
    _summaryAnimToken++;
    final token = _summaryAnimToken;
    final result = await _TimesHighScores.record(
      score: _sessionScore,
      at: finishedAt,
      storageKey: TimesTablesScreen.highScoreKey,
    );
    if (!mounted) return;
    setState(() {
      _phase = _TimesPhase.summary;
      _remainingMs = 0;
      _highScores = result.board;
      _highlightHighScoreIndex = result.insertedIndex;
      _summaryVisibleRows = 0;
      _summaryShowTotal = false;
      _summaryShowBoard = false;
    });
    const statsRows = 4;
    for (var i = 1; i <= statsRows; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted || token != _summaryAnimToken) return;
      setState(() => _summaryVisibleRows = i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || token != _summaryAnimToken) return;
    setState(() => _summaryShowTotal = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || token != _summaryAnimToken) return;
    setState(() => _summaryShowBoard = true);
  }

  void _restart() {
    _summaryAnimToken++;
    _ticker?.cancel();
    setState(() => _phase = _TimesPhase.ready);
  }

  void _syncKeyboardFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_keyboardFocus.hasFocus) _keyboardFocus.requestFocus();
    });
  }

  int _pointsForStreak(int streak) {
    if (streak >= 10) return 3;
    if (streak >= 5) return 2;
    return 1;
  }

  void _submit() {
    if (_phase != _TimesPhase.racing) return;
    final parsed = int.tryParse(_answerText);
    if (parsed == null) return;
    if (parsed == _problem.product) {
      final nextStreak = _streak + 1;
      final points = _pointsForStreak(nextStreak);
      setState(() {
        _correct++;
        _streak = nextStreak;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _sessionScore += points;
        _answerText = '';
        _flashWrong = false;
        _problem = TimesTablesProblems.next(_random, avoid: _problem);
      });
    } else {
      setState(() {
        _misses++;
        _streak = 0;
        _answerText = '';
        _flashWrong = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _flashWrong = false);
      });
    }
  }

  void _appendDigit(String digit) {
    if (_phase != _TimesPhase.racing) return;
    if (digit == '.') return;
    if (_answerText.length >= 4) return;
    setState(() => _answerText += digit);
    final expected = '${_problem.product}';
    if (_answerText.length >= expected.length) _submit();
  }

  void _backspace() {
    if (_phase != _TimesPhase.racing || _answerText.isEmpty) return;
    setState(() => _answerText = _answerText.substring(0, _answerText.length - 1));
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_phase != _TimesPhase.racing) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final digit = _digitForKey(key);
    if (digit != null) {
      _appendDigit(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String? _digitForKey(LogicalKeyboardKey key) {
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
          _TimesPhase.ready => _buildReady(context),
          _TimesPhase.countdown || _TimesPhase.racing => Focus(
              focusNode: _keyboardFocus,
              onKeyEvent: _onHardwareKey,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _syncKeyboardFocus(),
                child: _phase == _TimesPhase.countdown
                    ? _buildCountdown(context)
                    : _buildRace(context),
              ),
            ),
          _TimesPhase.summary => _buildSummary(context),
        },
      ),
    );
  }

  Widget _closeRow({required String title}) {
    return Padding(
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
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closeRow(title: 'Times Tables'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Race the clock. Facts skip 1, 2, and 10.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppUiSizes.lg),
                SettingsRectChipGroup<int>(
                  title: 'Duration',
                  titlePadding: EdgeInsets.zero,
                  options: [
                    for (final seconds in _durations)
                      SettingsRectChipOption(
                        value: seconds,
                        label: '${seconds}s',
                      ),
                  ],
                  value: _durationSeconds,
                  onChanged: _setDuration,
                ),
                const Spacer(),
                PrimaryActionButton(
                  text: 'Start race',
                  icon: Icons.play_arrow,
                  onPressed: _startCountdown,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closeRow(title: 'Times Tables'),
        Expanded(
          child: Center(
            child: Text(
              '$_countdownLeft',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRace(BuildContext context) {
    final progress = (_remainingMs / (_durationSeconds * 1000)).clamp(0.0, 1.0);
    final secondsLeft = (_remainingMs / 1000).ceil();
    final promptColor = _flashWrong
        ? AppColorPalette.error
        : AppColorPalette.textColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closeRow(title: 'Times Tables · ${secondsLeft}s'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                'Score $_sessionScore',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColorPalette.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$_correct correct · streak $_streak',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColorPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                Text(
                  _problem.prompt,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: promptColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppUiSizes.md),
                Text(
                  _answerText.isEmpty ? '·' : _answerText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _answerText.isEmpty
                        ? AppColorPalette.textSecondary
                        : AppColorPalette.textColor,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: CaseMathDigitPad(
                    compact: true,
                    onKeyTap: _appendDigit,
                    onBackspace: _backspace,
                    onAction: _submit,
                    actionLabel: 'Check',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final board = _highScores
        .map((e) => RetroScoreEntry(score: e.score, at: e.at))
        .toList();
    final stats = <(String, String)>[
      ('Correct', '$_correct'),
      ('Misses', '$_misses'),
      ('Best streak', '$_bestStreak'),
      ('Duration', '${_durationSeconds}s'),
    ];
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
            'Race complete',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$_correct facts in ${_durationSeconds}s',
            style: TextStyle(
              fontSize: 13,
              color: AppColorPalette.textSecondary,
            ),
          ),
          const SizedBox(height: AppUiSizes.md),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _summaryVisibleRows; i++)
                  _SummaryReveal(child: _statRow(stats[i].$1, stats[i].$2)),
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

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

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

class _TimesHighScore {
  const _TimesHighScore({required this.score, required this.at});

  final int score;
  final DateTime at;

  Map<String, int> toMap() => {
        'score': score,
        'atMs': at.millisecondsSinceEpoch,
      };

  static _TimesHighScore? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final atMs = raw['atMs'];
    if (score is! num || atMs is! num) return null;
    return _TimesHighScore(
      score: score.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(atMs.toInt()),
    );
  }
}

class _TimesHighScoreRecordResult {
  const _TimesHighScoreRecordResult({
    required this.board,
    required this.insertedIndex,
  });

  final List<_TimesHighScore> board;
  final int? insertedIndex;
}

class _TimesHighScores {
  static const _boxName = 'app_init_flags';
  static const _maxEntries = 10;

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<List<_TimesHighScore>> load(String storageKey) async {
    final box = await _box();
    final raw = box.get(storageKey);
    if (raw is! List) return const [];
    return raw
        .map(_TimesHighScore.fromMap)
        .whereType<_TimesHighScore>()
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.at.compareTo(a.at);
      });
  }

  static Future<_TimesHighScoreRecordResult> record({
    required int score,
    required DateTime at,
    required String storageKey,
  }) async {
    final entry = _TimesHighScore(score: score, at: at);
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
    return _TimesHighScoreRecordResult(
      board: trimmed,
      insertedIndex: insertedIndex >= 0 ? insertedIndex : null,
    );
  }
}

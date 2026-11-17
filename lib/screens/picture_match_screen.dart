import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/collectible_deck_seed_service.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/games/retro_scoreboard.dart';

enum _MatchPhase { loading, ready, playing, summary }

/// Picture quiz over the `cards_128x185.csv` decks: one image, four
/// title + description choices, pick the one that matches.
class PictureMatchScreen extends StatefulWidget {
  const PictureMatchScreen({super.key, this.exitLabel = 'Back to games'});

  final String exitLabel;

  static const highScoreKey = 'picture_match_high_scores';
  static const deckKey = 'picture_match_deck';
  static const roundsKey = 'picture_match_rounds';

  @override
  State<PictureMatchScreen> createState() => _PictureMatchScreenState();
}

class _MatchCard {
  const _MatchCard({
    required this.id,
    required this.title,
    required this.blurb,
    required this.category,
    required this.imageAsset,
    required this.quarterTurns,
  });

  final String id;
  final String title;
  final String blurb;
  final String category;
  final String imageAsset;
  final int quarterTurns;

  static _MatchCard? tryFrom(CardModel card, Set<String> assets) {
    final meta = card.metadata;
    if (meta['source'] != 'cards_128x185_csv') return null;
    final asset = meta['imageAsset'];
    if (asset is! String || !assets.contains(asset)) return null;
    final rotateRaw = meta['imageRotateDegrees'];
    final degrees = rotateRaw is num ? rotateRaw.toInt() : 0;
    return _MatchCard(
      id: card.id,
      title: card.title,
      blurb: _firstSegment(card.description),
      category: card.category,
      imageAsset: asset,
      quarterTurns: (degrees ~/ 90) % 4,
    );
  }

  /// Deck descriptions join short facts with `; `; the first reads as a blurb.
  static String _firstSegment(String description) {
    final first = description.split('; ').first.trim();
    return first.isEmpty ? description.trim() : first;
  }
}

class _MatchRound {
  const _MatchRound({required this.answer, required this.options});

  final _MatchCard answer;
  final List<_MatchCard> options;
}

class _AnsweredChip {
  const _AnsweredChip({required this.card, required this.correct});

  final _MatchCard card;
  final bool correct;
}

class _PictureMatchScreenState extends State<PictureMatchScreen> {
  static const _allDecks = 'all';
  static const _roundOptions = [10, 15, 20];
  static const _optionCount = 4;
  static const _revealDelay = Duration(milliseconds: 1100);

  final _random = Random();
  final _keyboardFocus = FocusNode();

  _MatchPhase _phase = _MatchPhase.loading;
  String? _error;
  List<_MatchCard> _pool = const [];
  String _deck = _allDecks;
  int _roundsPerSession = 10;

  List<_MatchRound> _rounds = const [];
  int _roundIndex = 0;
  int? _pickedIndex;
  int _correct = 0;
  int _misses = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _sessionScore = 0;
  int _answerToken = 0;

  /// Answer trail for the top bar (green / red bordered miniatures).
  final List<_AnsweredChip> _answered = [];

  /// Misses in the current pass — replayed until the pass is clean.
  final List<_MatchCard> _passMisses = [];

  List<_MatchHighScore> _highScores = const [];
  int? _highlightHighScoreIndex;
  int _summaryVisibleRows = 0;
  bool _summaryShowTotal = false;
  bool _summaryShowBoard = false;
  int _summaryAnimToken = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await CollectibleDeckSeedService.ensureSeeded();
      const boxName = 'motivationItems';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<CardModel>(boxName);
      }
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      final pool = Hive.box<CardModel>(boxName).values
          .map((c) => _MatchCard.tryFrom(c, assets))
          .whereType<_MatchCard>()
          .toList();

      final prefs = await _MatchHighScores._box();
      final storedDeck = prefs.get(PictureMatchScreen.deckKey);
      final storedRounds = prefs.get(PictureMatchScreen.roundsKey);
      if (!mounted) return;
      setState(() {
        _pool = pool;
        if (storedDeck is String && _deckOptions.contains(storedDeck)) {
          _deck = storedDeck;
        }
        if (storedRounds is num &&
            _roundOptions.contains(storedRounds.toInt())) {
          _roundsPerSession = storedRounds.toInt();
        }
        _phase = _MatchPhase.ready;
        _error = pool.length < _optionCount
            ? 'Not enough picture cards yet. Re-seed the catalog.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _MatchPhase.ready;
        _error = 'Could not load cards: $e';
      });
    }
  }

  /// `all` plus every category with enough cards for a full set of choices.
  List<String> get _deckOptions {
    final counts = <String, int>{};
    for (final c in _pool) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final cats =
        counts.entries
            .where((e) => e.value >= _optionCount)
            .map((e) => e.key)
            .toList()
          ..sort();
    return [_allDecks, ...cats];
  }

  List<_MatchCard> get _deckPool => _deck == _allDecks
      ? _pool
      : _pool.where((c) => c.category == _deck).toList();

  Future<void> _setDeck(String deck) async {
    setState(() => _deck = deck);
    final box = await _MatchHighScores._box();
    await box.put(PictureMatchScreen.deckKey, deck);
  }

  Future<void> _setRounds(int rounds) async {
    setState(() => _roundsPerSession = rounds);
    final box = await _MatchHighScores._box();
    await box.put(PictureMatchScreen.roundsKey, rounds);
  }

  /// Distractors come from the answer's own category first so choices feel
  /// plausible (birds vs birds, places vs places), then fall back to the pool.
  List<_MatchRound> _buildRounds() {
    final deck = [..._deckPool]..shuffle(_random);
    final answers = deck.take(min(_roundsPerSession, deck.length));
    return [
      for (final answer in answers)
        _MatchRound(answer: answer, options: _optionsFor(answer, deck)),
    ];
  }

  List<_MatchCard> _optionsFor(_MatchCard answer, List<_MatchCard> deck) {
    final sameCategory =
        _pool
            .where((c) => c.category == answer.category && c.id != answer.id)
            .toList()
          ..shuffle(_random);
    final picks = <_MatchCard>[answer];
    final titles = {answer.title.toLowerCase()};
    void addFrom(Iterable<_MatchCard> source) {
      for (final c in source) {
        if (picks.length >= _optionCount) return;
        if (titles.add(c.title.toLowerCase())) picks.add(c);
      }
    }

    addFrom(sameCategory);
    if (picks.length < _optionCount) {
      addFrom([..._pool]..shuffle(_random));
    }
    return picks..shuffle(_random);
  }

  void _start() {
    _summaryAnimToken++;
    final rounds = _buildRounds();
    if (rounds.isEmpty) return;
    setState(() {
      _rounds = rounds;
      _roundIndex = 0;
      _pickedIndex = null;
      _correct = 0;
      _misses = 0;
      _streak = 0;
      _bestStreak = 0;
      _sessionScore = 0;
      _answered.clear();
      _passMisses.clear();
      _phase = _MatchPhase.playing;
    });
    _syncKeyboardFocus();
  }

  int _pointsForStreak(int streak) {
    if (streak >= 8) return 3;
    if (streak >= 4) return 2;
    return 1;
  }

  void _pick(int index) {
    if (_phase != _MatchPhase.playing || _pickedIndex != null) return;
    final round = _rounds[_roundIndex];
    if (index < 0 || index >= round.options.length) return;
    final isCorrect = round.options[index].id == round.answer.id;
    final token = ++_answerToken;
    setState(() {
      _pickedIndex = index;
      _answered.add(
        _AnsweredChip(card: round.answer, correct: isCorrect),
      );
      if (isCorrect) {
        _correct++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _sessionScore += _pointsForStreak(_streak);
      } else {
        _misses++;
        _streak = 0;
        _passMisses.add(round.answer);
      }
    });
    Future<void>.delayed(_revealDelay, () {
      if (!mounted || token != _answerToken) return;
      _advance();
    });
  }

  void _advance() {
    if (_phase != _MatchPhase.playing || _pickedIndex == null) return;
    _answerToken++;
    if (_roundIndex + 1 >= _rounds.length) {
      if (_passMisses.isNotEmpty) {
        _startMissedPass();
        return;
      }
      _finish();
      return;
    }
    setState(() {
      _roundIndex++;
      _pickedIndex = null;
    });
  }

  /// Replay only cards missed in the last pass until a clean pass.
  void _startMissedPass() {
    final missed = [..._passMisses]..shuffle(_random);
    final deck = _deckPool;
    setState(() {
      _passMisses.clear();
      _rounds = [
        for (final answer in missed)
          _MatchRound(answer: answer, options: _optionsFor(answer, deck)),
      ];
      _roundIndex = 0;
      _pickedIndex = null;
    });
    _syncKeyboardFocus();
  }

  Future<void> _finish() async {
    _summaryAnimToken++;
    final token = _summaryAnimToken;
    final result = await _MatchHighScores.record(
      score: _sessionScore,
      at: DateTime.now(),
      storageKey: PictureMatchScreen.highScoreKey,
    );
    if (!mounted) return;
    setState(() {
      _phase = _MatchPhase.summary;
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
    _answerToken++;
    setState(() => _phase = _MatchPhase.ready);
  }

  void _syncKeyboardFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_keyboardFocus.hasFocus) _keyboardFocus.requestFocus();
    });
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_phase != _MatchPhase.playing) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_pickedIndex != null &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      _advance();
      return KeyEventResult.handled;
    }
    const keys = [
      [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
      [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
      [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
      [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
    ];
    for (var i = 0; i < keys.length; i++) {
      if (keys[i].contains(key)) {
        _pick(i);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: switch (_phase) {
          _MatchPhase.loading => Column(
            children: [
              _closeRow(title: 'Picture Match'),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
          _MatchPhase.ready => _buildReady(context),
          _MatchPhase.playing => Focus(
            focusNode: _keyboardFocus,
            onKeyEvent: _onHardwareKey,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _syncKeyboardFocus(),
              child: _buildRound(context),
            ),
          ),
          _MatchPhase.summary => _buildSummary(context),
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  static String _deckLabel(String deck) {
    if (deck == _allDecks) return 'All';
    if (deck.isEmpty) return deck;
    return deck[0].toUpperCase() + deck.substring(1);
  }

  Widget _buildReady(BuildContext context) {
    final deckCount = _deckPool.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closeRow(title: 'Picture Match'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Match the picture to its card. Streaks score extra.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorPalette.textColor,
                  ),
                ),
                const SizedBox(height: AppUiSizes.lg),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: AppColorPalette.error))
                else ...[
                  SettingsRectChipGroup<String>(
                    title: 'Deck',
                    titlePadding: EdgeInsets.zero,
                    options: [
                      for (final deck in _deckOptions)
                        SettingsRectChipOption(
                          value: deck,
                          label: _deckLabel(deck),
                        ),
                    ],
                    value: _deck,
                    onChanged: _setDeck,
                  ),
                  const SizedBox(height: AppUiSizes.lg),
                  SettingsRectChipGroup<int>(
                    title: 'Rounds',
                    titlePadding: EdgeInsets.zero,
                    options: [
                      for (final rounds in _roundOptions)
                        SettingsRectChipOption(value: rounds, label: '$rounds'),
                    ],
                    value: _roundsPerSession,
                    onChanged: _setRounds,
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Text(
                    '$deckCount cards in this deck',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColorPalette.textColor,
                    ),
                  ),
                ],
                const Spacer(),
                PrimaryActionButton(
                  text: 'Start',
                  icon: Icons.play_arrow,
                  onPressed: _error == null && deckCount > 0 ? _start : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRound(BuildContext context) {
    final round = _rounds[_roundIndex];
    final progress =
        (_roundIndex + (_pickedIndex != null ? 1 : 0)) / _rounds.length;
    final revealed = _pickedIndex != null;
    final pictureWidth = (MediaQuery.sizeOf(context).width * 0.34).clamp(
      96.0,
      132.0,
    );
    final pictureHeight = pictureWidth / CollectibleCardLayout.aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              Expanded(child: _buildAnswerTrail()),
              if (_streak > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'streak $_streak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).primaryColor,
                    ),
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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < round.options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Expanded(
                        child: _OptionTile(
                          index: i,
                          card: round.options[i],
                          state: _optionState(round, i),
                          onTap: revealed ? null : () => _pick(i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                width: pictureWidth,
                height: pictureHeight,
                child: IgnorePointer(
                  child: _MatchPicture(
                    key: ValueKey(round.answer.id),
                    card: round.answer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerTrail() {
    if (_answered.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Index 0 sits on the right → newest chip first.
        reverse: true,
        itemCount: _answered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final chip = _answered[_answered.length - 1 - i];
          return _ResultMini(card: chip.card, correct: chip.correct);
        },
      ),
    );
  }

  _OptionState _optionState(_MatchRound round, int index) {
    final picked = _pickedIndex;
    if (picked == null) return _OptionState.idle;
    final isAnswer = round.options[index].id == round.answer.id;
    if (isAnswer) return _OptionState.correct;
    if (index == picked) return _OptionState.wrong;
    return _OptionState.dimmed;
  }

  Widget _buildSummary(BuildContext context) {
    final board = _highScores
        .map((e) => RetroScoreEntry(score: e.score, at: e.at))
        .toList();
    final stats = <(String, String)>[
      ('Correct', '$_correct'),
      ('Misses', '$_misses'),
      ('Best streak', '$_bestStreak'),
      ('Deck', _deckLabel(_deck)),
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
            'Round complete',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$_correct correct · $_misses misses',
            style: TextStyle(fontSize: 13, color: AppColorPalette.textColor),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The round's picture, upright (CSV `r` cards are stored turned and get
/// their quarter turn back here) on the white page the scans assume.
class _MatchPicture extends StatelessWidget {
  const _MatchPicture({super.key, required this.card});

  final _MatchCard card;

  @override
  Widget build(BuildContext context) {
    return _SummaryReveal(
      child: RotatedBox(
        quarterTurns: card.quarterTurns,
        child: Image.asset(
          card.imageAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_not_supported_outlined,
            color: AppColorPalette.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Tiny answer trail chip for the play top bar.
class _ResultMini extends StatelessWidget {
  const _ResultMini({required this.card, required this.correct});

  final _MatchCard card;
  final bool correct;

  static const double _width = 22;

  @override
  Widget build(BuildContext context) {
    final border = correct ? AppColorPalette.success : AppColorPalette.error;
    final height = _width / CollectibleCardLayout.aspectRatio;
    return Container(
      width: _width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(3),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: RotatedBox(
        quarterTurns: card.quarterTurns,
        child: Image.asset(
          card.imageAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: AppColorPalette.grey300,
            child: Icon(
              correct ? Icons.check : Icons.close,
              size: 10,
              color: border,
            ),
          ),
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.card,
    required this.state,
    required this.onTap,
  });

  final int index;
  final _MatchCard card;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final (Color border, Color? fill) = switch (state) {
      _OptionState.correct => (
        AppColorPalette.success,
        AppColorPalette.success.withValues(alpha: 0.16),
      ),
      _OptionState.wrong => (
        AppColorPalette.error,
        AppColorPalette.error.withValues(alpha: 0.14),
      ),
      _OptionState.dimmed => (Colors.black26, null),
      _OptionState.idle => (Colors.black, null),
    };
    final faded = state == _OptionState.dimmed;
    final icon = switch (state) {
      _OptionState.correct => Icons.check_circle,
      _OptionState.wrong => Icons.cancel,
      _ => null,
    };

    return Material(
      color: fill ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: 0.8),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: primary.withValues(alpha: 0.12),
        child: Opacity(
          opacity: faded ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}  ${card.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColorPalette.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          card.blurb,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: AppColorPalette.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: border, size: 20),
                ],
              ],
            ),
          ),
        ),
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

class _MatchHighScore {
  const _MatchHighScore({required this.score, required this.at});

  final int score;
  final DateTime at;

  Map<String, int> toMap() => {
    'score': score,
    'atMs': at.millisecondsSinceEpoch,
  };

  static _MatchHighScore? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final atMs = raw['atMs'];
    if (score is! num || atMs is! num) return null;
    return _MatchHighScore(
      score: score.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(atMs.toInt()),
    );
  }
}

class _MatchHighScoreRecordResult {
  const _MatchHighScoreRecordResult({
    required this.board,
    required this.insertedIndex,
  });

  final List<_MatchHighScore> board;
  final int? insertedIndex;
}

class _MatchHighScores {
  static const _boxName = 'app_init_flags';
  static const _maxEntries = 10;

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static int _byScoreThenRecent(_MatchHighScore a, _MatchHighScore b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return b.at.compareTo(a.at);
  }

  static Future<List<_MatchHighScore>> load(String storageKey) async {
    final box = await _box();
    final raw = box.get(storageKey);
    if (raw is! List) return const [];
    return raw
        .map(_MatchHighScore.fromMap)
        .whereType<_MatchHighScore>()
        .toList()
      ..sort(_byScoreThenRecent);
  }

  static Future<_MatchHighScoreRecordResult> record({
    required int score,
    required DateTime at,
    required String storageKey,
  }) async {
    final entry = _MatchHighScore(score: score, at: at);
    final board = [...await load(storageKey), entry]..sort(_byScoreThenRecent);
    final trimmed = board.take(_maxEntries).toList();
    final insertedIndex = trimmed.indexWhere(
      (e) =>
          e.score == entry.score &&
          e.at.millisecondsSinceEpoch == entry.at.millisecondsSinceEpoch,
    );
    final box = await _box();
    await box.put(storageKey, trimmed.map((e) => e.toMap()).toList());
    return _MatchHighScoreRecordResult(
      board: trimmed,
      insertedIndex: insertedIndex >= 0 ? insertedIndex : null,
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/chrono_atlas_map_config.dart';
import 'package:solo_level_system/utils/chrono_atlas_scoring.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';
import 'package:solo_level_system/widgets/common/settings_slider.dart';
import 'package:solo_level_system/widgets/game_icon_widget.dart';
import 'package:solo_level_system/widgets/games/retro_scoreboard.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

/// A round asks for one thing only: where it belongs, or when it happened.
enum _RoundMode { place, year }

enum _RoundPhase { guess, reveal, summary }

class ChronoAtlasScreen extends StatefulWidget {
  const ChronoAtlasScreen({super.key, this.roundsPerSession = 5});

  final int roundsPerSession;

  @override
  State<ChronoAtlasScreen> createState() => _ChronoAtlasScreenState();
}

class _ChronoAtlasScreenState extends State<ChronoAtlasScreen> {
  static const String _boxName = 'motivationItems';

  /// Timeline bounds, wide enough for the whole catalog and answer-agnostic.
  static const int _minYear = -700;
  static final int _maxYear = DateTime.now().year;

  /// First place-tap zoom: nearby countries visible for finer placement.
  static const double _placeDetailZoom = 5.0;

  /// Slightly above world-fit so a tall phone viewport fills with map (no
  /// empty bands under the tiles).
  static const double _worldZoom = 2.15;
  static const double _overlayCardWidth = 108.0;

  bool _loading = true;
  String? _error;
  List<_Round> _deck = const [];
  int _roundIndex = 0;
  int _sessionScore = 0;
  _RoundPhase _phase = _RoundPhase.guess;

  MapLatLng? _guessLatLng;
  late MapTileLayerController _tileController;
  late MapShapeLayerController _shapeController;
  late MapShapeSource _shapeSource;
  late _TapZoomPanBehavior _zoomPanBehavior;
  bool _zoomedToGuess = false;

  /// Camera restored by reset: round start, or the place pin after first drop.
  MapLatLng _homeFocal = const MapLatLng(20, 10);
  double _homeZoom = _worldZoom;

  late int _yearGuess;

  ChronoAtlasGeoResult? _geoResult;
  ChronoAtlasYearResult? _yearResult;
  final List<int> _roundScores = [];

  List<_MarkerSpec> _markers = const [];
  UserProgressModel? _userProgress;

  List<_ChronoHighScore> _highScores = const [];
  DateTime? _sessionFinishedAt;
  int? _highlightHighScoreIndex;

  /// Summary reveal: round rows → total → scoreboard (~200ms steps).
  int _summaryVisibleRows = 0;
  bool _summaryShowTotal = false;
  bool _summaryShowBoard = false;
  int _summaryAnimToken = 0;

  @override
  void initState() {
    super.initState();
    _createMapControllers();
    _yearGuess = _defaultYear;
    _bootstrap();
  }

  void _createMapControllers() {
    _tileController = MapTileLayerController();
    _shapeController = MapShapeLayerController();
    _shapeSource = MapShapeSource.asset(
      ChronoAtlasMapConfig.shapeAsset,
      shapeDataField: ChronoAtlasMapConfig.shapeDataField,
    );
    _zoomPanBehavior = _TapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomLevel: _worldZoom,
      minZoomLevel: 1,
      maxZoomLevel: 8,
      focalLatLng: const MapLatLng(20, 10),
      showToolbar: false,
    )..onTap = _onMapTap;
  }

  static int get _defaultYear => ((_minYear + _maxYear) / 2).round();

  Future<void> _bootstrap() async {
    try {
      await MotivationSeedService.ensureSeeded();
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<CardModel>(_boxName);
      }
      if (!Hive.isBoxOpen('userProgress')) {
        await Hive.openBox<UserProgressModel>('userProgress');
      }
      _userProgress = Hive.box<UserProgressModel>(
        'userProgress',
      ).get('progress');

      final box = Hive.box<CardModel>(_boxName);
      final playable = box.values
          .map(_PlayableCard.tryFrom)
          .whereType<_PlayableCard>()
          .toList();
      if (playable.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No Chrono Atlas cards found. Re-seed the catalog.';
        });
        return;
      }
      final rng = math.Random();
      playable.shuffle(rng);
      final take = math.min(widget.roundsPerSession, playable.length);
      final deck = playable
          .take(take)
          .map((card) => _Round(card: card, mode: _pickMode(card, rng)))
          .toList();
      if (!mounted) return;
      setState(() {
        _deck = deck;
        _loading = false;
        _error = null;
        _phase = _RoundPhase.guess;
        _roundIndex = 0;
      });
      // Wait for SfMaps to mount with the fresh controller before mutating
      // zoom/markers — otherwise Play again hits "Unexpected null value".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _deck.isEmpty) return;
        setState(_startRound);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load Chrono Atlas: $e';
      });
    }
  }

  /// Cards carrying both signals become a coin flip; others use what they have.
  static _RoundMode _pickMode(_PlayableCard card, math.Random rng) {
    if (card.hasPins && card.hasYear) {
      return rng.nextBool() ? _RoundMode.place : _RoundMode.year;
    }
    return card.hasPins ? _RoundMode.place : _RoundMode.year;
  }

  _Round get _current => _deck[_roundIndex];

  /// Year rounds hand the location over for free; place rounds start blank.
  void _startRound() {
    final round = _current;
    _guessLatLng = null;
    _yearGuess = _defaultYear;
    _geoResult = null;
    _yearResult = null;
    _zoomedToGuess = false;

    if (round.mode == _RoundMode.year && round.card.hasPins) {
      final pin = round.card.pins.first;
      final focal = MapLatLng(pin.lat, pin.lng);
      _zoomPanBehavior.zoomLevel = 4;
      _zoomPanBehavior.focalLatLng = focal;
      _setHomeView(focal, 4);
      _setMarkers(
        round.card.pins
            .map((p) => _MarkerSpec(lat: p.lat, lng: p.lng, isGuess: false))
            .toList(),
      );
    } else {
      const focal = MapLatLng(20, 10);
      _zoomPanBehavior.zoomLevel = _worldZoom;
      _zoomPanBehavior.focalLatLng = focal;
      _setHomeView(focal, _worldZoom);
      _setMarkers(const []);
    }
  }

  void _setHomeView(MapLatLng focal, double zoom) {
    _homeFocal = focal;
    _homeZoom = zoom;
  }

  void _setMarkers(List<_MarkerSpec> markers) {
    _markers = markers;
    // Controllers are only attached while the map is in the tree (not on
    // summary / loading). Skip sync when detached so Play again can restart.
    try {
      if (ChronoAtlasMapConfig.useOfflineShape) {
        _shapeController.clearMarkers();
        for (var i = 0; i < markers.length; i++) {
          _shapeController.insertMarker(i);
        }
      } else {
        _tileController.clearMarkers();
        for (var i = 0; i < markers.length; i++) {
          _tileController.insertMarker(i);
        }
      }
    } catch (_) {
      // Detached controller — markers apply on next map mount via
      // initialMarkersCount / a later _setMarkers after _startRound.
    }
  }

  void _onMapTap(Offset localPosition) {
    if (_phase != _RoundPhase.guess) return;
    if (_current.mode != _RoundMode.place) return;
    final latLng = ChronoAtlasMapConfig.useOfflineShape
        ? _shapeController.pixelToLatLng(localPosition)
        : _tileController.pixelToLatLng(localPosition);
    final firstTap = !_zoomedToGuess;
    setState(() {
      _guessLatLng = latLng;
      _setMarkers([
        _MarkerSpec(lat: latLng.latitude, lng: latLng.longitude, isGuess: true),
      ]);
      if (firstTap) {
        _zoomedToGuess = true;
        _zoomPanBehavior.zoomLevel = _placeDetailZoom;
        _zoomPanBehavior.focalLatLng = latLng;
        _setHomeView(latLng, _placeDetailZoom);
      } else {
        // Keep detail zoom; gently re-center on the new pin.
        _zoomPanBehavior.focalLatLng = latLng;
        _setHomeView(latLng, _placeDetailZoom);
      }
    });
  }

  void _confirmGuess() {
    final round = _current;
    ChronoAtlasGeoResult? geo;
    ChronoAtlasYearResult? year;
    var score = 0;

    if (round.mode == _RoundMode.place) {
      if (_guessLatLng == null) return;
      geo = ChronoAtlasScoring.scoreGeo(
        guessLat: _guessLatLng!.latitude,
        guessLng: _guessLatLng!.longitude,
        pins: round.card.pins,
      );
      score = geo.score;
      _setMarkers([
        _MarkerSpec(
          lat: _guessLatLng!.latitude,
          lng: _guessLatLng!.longitude,
          isGuess: true,
        ),
        ...round.card.pins.map(
          (p) => _MarkerSpec(lat: p.lat, lng: p.lng, isGuess: false),
        ),
      ]);
    } else {
      year = ChronoAtlasScoring.scoreYear(
        guess: _yearGuess,
        answer: round.card.year!,
      );
      score = year.score;
    }

    setState(() {
      _geoResult = geo;
      _yearResult = year;
      _sessionScore += score;
      _roundScores.add(score);
      _phase = _RoundPhase.reveal;
    });
  }

  void _nextRound() {
    if (_roundIndex >= _deck.length - 1) {
      unawaited(_enterSummary());
      return;
    }
    setState(() {
      _roundIndex++;
      _phase = _RoundPhase.guess;
      _startRound();
    });
  }

  Future<void> _enterSummary() async {
    final finishedAt = DateTime.now();
    final recorded = await _ChronoAtlasHighScores.record(
      score: _sessionScore,
      at: finishedAt,
    );
    if (!mounted) return;
    setState(() {
      _phase = _RoundPhase.summary;
      _sessionFinishedAt = finishedAt;
      _highScores = recorded.board;
      _highlightHighScoreIndex = recorded.insertedIndex;
      _summaryVisibleRows = 0;
      _summaryShowTotal = false;
      _summaryShowBoard = false;
    });
    unawaited(_runSummaryReveal());
  }

  Future<void> _runSummaryReveal() async {
    final token = ++_summaryAnimToken;
    const step = Duration(milliseconds: 200);

    for (var i = 0; i < _deck.length; i++) {
      await Future<void>.delayed(step);
      if (!mounted || token != _summaryAnimToken) return;
      if (_phase != _RoundPhase.summary) return;
      setState(() => _summaryVisibleRows = i + 1);
    }

    await Future<void>.delayed(step);
    if (!mounted || token != _summaryAnimToken) return;
    if (_phase != _RoundPhase.summary) return;
    setState(() => _summaryShowTotal = true);

    await Future<void>.delayed(step);
    if (!mounted || token != _summaryAnimToken) return;
    if (_phase != _RoundPhase.summary) return;
    setState(() => _summaryShowBoard = true);
  }

  Future<void> _restart() async {
    setState(() {
      _loading = true;
      _error = null;
      _deck = const [];
      _roundIndex = 0;
      _sessionScore = 0;
      _roundScores.clear();
      _guessLatLng = null;
      _yearGuess = _defaultYear;
      _geoResult = null;
      _yearResult = null;
      _zoomedToGuess = false;
      _highScores = const [];
      _sessionFinishedAt = null;
      _highlightHighScoreIndex = null;
      _summaryVisibleRows = 0;
      _summaryShowTotal = false;
      _summaryShowBoard = false;
      _summaryAnimToken++;
      _markers = const [];
      _phase = _RoundPhase.guess;
      // Fresh controllers — old ones stay tied to the disposed summary-era map.
      _createMapControllers();
    });
    await _bootstrap();
  }

  Future<void> _openObjectiveCard() async {
    final progress = _userProgress;
    if (progress == null || !mounted) return;
    final catalog = CardRepository.fromCardModel(_current.card.source);
    await showCollectibleCardDetail(
      context: context,
      card: catalog,
      userProgress: progress,
      allowAcquire: false,
      // Place / year stay hidden until the player confirms their guess.
      hideCatalogFacts: _phase == _RoundPhase.guess,
    );
  }

  /// Keep current zoom; pan so the solution pin sits in the center.
  void _centerOnSolution() {
    final pin =
        _geoResult?.nearestPin ??
        (_current.card.pins.isNotEmpty ? _current.card.pins.first : null);
    if (pin == null) return;
    setState(() {
      _zoomPanBehavior.focalLatLng = MapLatLng(pin.lat, pin.lng);
    });
  }

  void _zoomBy(double delta) {
    final next = (_zoomPanBehavior.zoomLevel + delta).clamp(
      _zoomPanBehavior.minZoomLevel,
      _zoomPanBehavior.maxZoomLevel,
    );
    if (next == _zoomPanBehavior.zoomLevel) return;
    setState(() => _zoomPanBehavior.zoomLevel = next);
  }

  void _resetMapView() {
    setState(() {
      _zoomPanBehavior.zoomLevel = _homeZoom;
      _zoomPanBehavior.focalLatLng = _homeFocal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorPalette.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SafeArea(
        child: Stack(
          children: [
            _buildExitButton(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }
    if (_phase == _RoundPhase.summary) {
      return SafeArea(child: _buildSummary());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Force the tile map to the full scaffold — otherwise SfMaps sizes to
        // its intrinsic tile strip and leaves a white band under the map.
        Positioned.fill(child: _buildMap()),
        // Pin exit + instructions to the top (do not share bottom panel space).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(bottom: false, child: _buildTopChrome()),
        ),
        SafeArea(child: _buildObjectiveCardOverlay()),
        SafeArea(child: _buildZoomControls()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(top: false, child: _buildBottomPanel()),
        ),
        Positioned(
          left: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          child: Text(
            ChronoAtlasMapConfig.useOfflineShape ? '' : '© OpenStreetMap',
            style: TextStyle(
              color: AppColorPalette.grey700,
              fontSize: 10,
              backgroundColor: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExitButton() {
    return Positioned(
      top: 4,
      left: 4,
      child: _mapIconButton(
        icon: Icons.close,
        tooltip: 'Exit',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Top row: bare exit · place hint (year scrubber lives at the bottom).
  Widget _buildTopChrome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _mapIconButton(
            icon: Icons.close,
            tooltip: 'Exit',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child:
                _current.mode == _RoundMode.place && _phase == _RoundPhase.guess
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Tap the map where this belongs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColorPalette.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 6),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Keep the far right clear for the objective card.
          const SizedBox(width: _overlayCardWidth + 8),
        ],
      ),
    );
  }

  /// Year scrubber (full width) sits above solution / score / confirm.
  Widget _buildBottomPanel() {
    final yearMode = _current.mode == _RoundMode.year;
    final showReveal = _phase == _RoundPhase.reveal;
    final showConfirm =
        _phase == _RoundPhase.guess &&
        (_current.mode != _RoundMode.place || _guessLatLng != null);

    if (!yearMode && !showReveal && !showConfirm) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (yearMode) ...[_buildYearScrubber(), const SizedBox(height: 10)],
            if (showReveal) ...[
              _buildSolutionCard(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildSessionScoreChip(),
              ),
            ],
            if (showConfirm)
              Align(
                alignment: Alignment.centerRight,
                child: CustomFloatingActionButton(
                  heroTag: 'chrono_atlas_action',
                  label: 'Confirm',
                  icon: Icons.check,
                  onPressed: _confirmGuess,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearScrubber() {
    final locked = _phase != _RoundPhase.guess;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatYear(_yearGuess).toLowerCase(),
          style: TextStyle(
            color: AppColorPalette.textColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            shadows: const [Shadow(color: Colors.white, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 2),
        SettingsSlider(
          value: _yearGuess.toDouble(),
          min: _minYear.toDouble(),
          max: _maxYear.toDouble(),
          onChanged: locked
              ? null
              : (value) => setState(() => _yearGuess = value.round()),
        ),
      ],
    );
  }

  Widget _buildObjectiveCardOverlay() {
    final catalog = CardRepository.fromCardModel(_current.card.source);
    final cardHeight = _overlayCardWidth / CollectibleCardLayout.aspectRatio;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 10, top: 48),
        child: SizedBox(
          width: _overlayCardWidth,
          height: cardHeight,
          child: Material(
            elevation: 5,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
            child: CollectibleCardTile(
              card: catalog,
              forceRevealContents: true,
              availablePoints: _userProgress?.availablePoints,
              onTap: _openObjectiveCard,
            ),
          ),
        ),
      ),
    );
  }

  /// Vertical zoom stack on the right edge, under the objective card.
  Widget _buildZoomControls() {
    final cardHeight = _overlayCardWidth / CollectibleCardLayout.aspectRatio;
    final topInset = 48.0 + cardHeight + 8;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(right: 6, top: topInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _mapIconButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: () => _zoomBy(1),
            ),
            _mapIconButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: () => _zoomBy(-1),
            ),
            _mapIconButton(
              icon: Icons.center_focus_strong,
              tooltip: 'Reset view',
              onPressed: _resetMapView,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (ChronoAtlasMapConfig.useOfflineShape) {
      final scheme = Theme.of(context).colorScheme;
      return SfMaps(
        key: ObjectKey(_shapeController),
        layers: [
          MapShapeLayer(
            source: _shapeSource,
            zoomPanBehavior: _zoomPanBehavior,
            controller: _shapeController,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
            strokeColor: scheme.outline.withValues(alpha: 0.55),
            strokeWidth: 0.6,
            initialMarkersCount: _markers.length,
            markerBuilder: _mapMarkerBuilder,
          ),
        ],
      );
    }

    // Preserved online tile implementation for later connectivity switching.
    return SfMaps(
      key: ObjectKey(_tileController),
      layers: [
        MapTileLayer(
          urlTemplate: ChronoAtlasMapConfig.tileUrlTemplate,
          zoomPanBehavior: _zoomPanBehavior,
          controller: _tileController,
          initialMarkersCount: _markers.length,
          markerBuilder: _mapMarkerBuilder,
        ),
      ],
    );
  }

  MapMarker _mapMarkerBuilder(BuildContext context, int index) {
    if (index < 0 || index >= _markers.length) {
      return const MapMarker(
        latitude: 0,
        longitude: 0,
        child: SizedBox.shrink(),
      );
    }
    final marker = _markers[index];
    return MapMarker(
      latitude: marker.lat,
      longitude: marker.lng,
      child: Icon(
        marker.isGuess ? Icons.location_on : Icons.flag,
        color: marker.isGuess ? Colors.redAccent : AppColorPalette.success,
        size: marker.isGuess ? 32 : 28,
      ),
    );
  }

  Widget _buildSolutionCard() {
    final round = _current;
    final canCenter = round.card.hasPins;
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      child: InkWell(
        onTap: canCenter ? _centerOnSolution : null,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRevealCopy(round)),
              if (canCenter)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.my_location,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealCopy(_Round round) {
    final primary = Theme.of(context).primaryColor;
    final canCenter = round.card.hasPins;
    final place = round.card.placeLabel;

    if (_geoResult != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place != null)
            Text(
              place,
              style: TextStyle(
                color: canCenter ? primary : AppColorPalette.textColor,
                fontWeight: FontWeight.w700,
                decoration: canCenter ? TextDecoration.underline : null,
                decorationColor: primary,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Off by ${_formatDistance(_geoResult!.distanceKm)} · '
            '+${_geoResult!.score}',
            style: TextStyle(color: AppColorPalette.textSecondary),
          ),
        ],
      );
    }

    if (_yearResult != null) {
      final yearLine =
          '${_formatYear(round.card.year!)} · '
          '${_yearResult!.deltaYears} yr · +${_yearResult!.score}';
      return Text(
        place != null ? '$place / $yearLine' : yearLine,
        style: TextStyle(
          color: canCenter ? primary : AppColorPalette.textColor,
          fontWeight: FontWeight.w600,
          height: 1.35,
          decorationColor: primary,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Running session total + round progress under the solution card.
  /// Tap to continue (replaces a separate Next / Results button).
  Widget _buildSessionScoreChip() {
    final last = _roundIndex >= _deck.length - 1;
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      child: InkWell(
        onTap: _nextRound,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'score: $_sessionScore  ${_roundIndex + 1}/${_deck.length}',
                style: TextStyle(
                  color: AppColorPalette.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                last ? Icons.flag_outlined : Icons.arrow_forward,
                size: 16,
                color: AppColorPalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icon-only control for map chrome (no white circular plate).
  Widget _mapIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        color: AppColorPalette.textColor,
        size: 26,
        shadows: const [
          Shadow(color: Colors.white, blurRadius: 8),
          Shadow(color: Colors.white, blurRadius: 4),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final boardEntries =
        (_highScores.isEmpty && _sessionFinishedAt != null
                ? [
                    _ChronoHighScore(
                      score: _sessionScore,
                      at: _sessionFinishedAt!,
                    ),
                  ]
                : _highScores)
            .map((e) => RetroScoreEntry(score: e.score, at: e.at))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _mapIconButton(
              icon: Icons.close,
              tooltip: 'Exit',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _summaryVisibleRows; i++)
                  _SummaryReveal(child: _buildSummaryRoundRow(i)),
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
                      entries: boardEntries,
                      highlightIndex: _highlightHighScoreIndex,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Center(
            child: CustomFloatingActionButton(
              heroTag: 'chrono_atlas_play_again',
              label: 'Play again',
              icon: Icons.replay,
              onPressed: _restart,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to games'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRoundRow(int i) {
    final round = _deck[i];
    final score = i < _roundScores.length ? _roundScores[i] : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (round.card.imageIndex != null)
            MotivationIconWidget(imageIndex: round.card.imageIndex!, size: 36)
          else
            const SizedBox(width: 36, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  round.card.title,
                  style: TextStyle(
                    color: AppColorPalette.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  round.mode == _RoundMode.place ? 'Place' : 'Year',
                  style: TextStyle(
                    color: AppColorPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            score > 0 ? '+$score' : '$score',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatYear(int year) {
    if (year < 0) return '${year.abs()} BCE';
    return '$year';
  }

  String _formatDistance(double km) {
    if (km < 1) return '<1 km';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}

/// Short fade + rise used by the Chrono Atlas summary stagger.
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

class _TapZoomPanBehavior extends MapZoomPanBehavior {
  _TapZoomPanBehavior({
    super.enablePanning,
    super.enablePinching,
    super.zoomLevel,
    super.minZoomLevel,
    super.maxZoomLevel,
    super.focalLatLng,
    super.showToolbar,
  });

  void Function(Offset localPosition)? onTap;
  Offset? _down;

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _down = event.localPosition;
    } else if (event is PointerUpEvent && _down != null) {
      // Ignore pan releases; only short taps place a guess.
      if ((event.localPosition - _down!).distance < 12) {
        onTap?.call(event.localPosition);
      }
      _down = null;
    }
    super.handleEvent(event);
  }
}

class _MarkerSpec {
  const _MarkerSpec({
    required this.lat,
    required this.lng,
    required this.isGuess,
  });

  final double lat;
  final double lng;
  final bool isGuess;
}

class _Round {
  const _Round({required this.card, required this.mode});

  final _PlayableCard card;
  final _RoundMode mode;
}

class _PlayableCard {
  const _PlayableCard({
    required this.source,
    required this.title,
    required this.category,
    required this.pins,
    this.year,
    this.yearKind,
    this.placeLabel,
    this.imageIndex,
  });

  final CardModel source;
  final String title;
  final String category;
  final List<ChronoAtlasPin> pins;
  final int? year;
  final String? yearKind;
  final String? placeLabel;
  final int? imageIndex;

  bool get hasPins => pins.isNotEmpty;
  bool get hasYear => year != null;

  static _PlayableCard? tryFrom(CardModel card) {
    final meta = card.metadata;
    final pins = <ChronoAtlasPin>[];
    final rawPins = meta['pins'];
    if (rawPins is List) {
      for (final item in rawPins) {
        if (item is Map) {
          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final radius = (item['radiusKm'] as num?)?.toDouble();
          pins.add(ChronoAtlasPin(lat: lat, lng: lng, radiusKm: radius));
        }
      }
    }
    final year = meta['year'] is int
        ? meta['year'] as int
        : int.tryParse('${meta['year'] ?? ''}');
    if (pins.isEmpty && year == null) return null;
    return _PlayableCard(
      source: card,
      title: card.title,
      category: card.category,
      pins: pins,
      year: year,
      yearKind: meta['yearKind'] as String?,
      placeLabel: meta['placeLabel'] as String?,
      imageIndex: card.imageIndex,
    );
  }
}

class _ChronoHighScore {
  const _ChronoHighScore({required this.score, required this.at});

  final int score;
  final DateTime at;

  Map<String, dynamic> toMap() => {
    'score': score,
    'atMs': at.millisecondsSinceEpoch,
  };

  static _ChronoHighScore? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final atMs = raw['atMs'];
    if (score is! num || atMs is! num) return null;
    return _ChronoHighScore(
      score: score.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(atMs.toInt()),
    );
  }
}

class _ChronoHighScoreRecordResult {
  const _ChronoHighScoreRecordResult({
    required this.board,
    required this.insertedIndex,
  });

  final List<_ChronoHighScore> board;
  final int? insertedIndex;
}

/// Persists Chrono Atlas session totals in [app_init_flags].
class _ChronoAtlasHighScores {
  static const _boxName = 'app_init_flags';
  static const _key = 'chrono_atlas_high_scores';
  static const _maxEntries = 10;

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<List<_ChronoHighScore>> load() async {
    final box = await _box();
    final raw = box.get(_key);
    if (raw is! List) return const [];
    final scores =
        raw.map(_ChronoHighScore.fromMap).whereType<_ChronoHighScore>().toList()
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            return b.at.compareTo(a.at);
          });
    return scores;
  }

  static Future<_ChronoHighScoreRecordResult> record({
    required int score,
    required DateTime at,
  }) async {
    final entry = _ChronoHighScore(score: score, at: at);
    final board = [...await load(), entry]
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
    await box.put(_key, trimmed.map((e) => e.toMap()).toList());
    return _ChronoHighScoreRecordResult(
      board: trimmed,
      insertedIndex: insertedIndex >= 0 ? insertedIndex : null,
    );
  }
}

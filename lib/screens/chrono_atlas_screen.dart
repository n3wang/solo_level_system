import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/chrono_atlas_scoring.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';
import 'package:solo_level_system/widgets/game_icon_widget.dart';
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
  late final MapTileLayerController _mapController;
  late final _TapZoomPanBehavior _zoomPanBehavior;
  bool _zoomedToGuess = false;

  late int _yearGuess;

  ChronoAtlasGeoResult? _geoResult;
  ChronoAtlasYearResult? _yearResult;
  int _roundScore = 0;
  final List<int> _roundScores = [];

  List<_MarkerSpec> _markers = const [];
  UserProgressModel? _userProgress;

  @override
  void initState() {
    super.initState();
    _mapController = MapTileLayerController();
    _zoomPanBehavior = _TapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomLevel: _worldZoom,
      minZoomLevel: 1,
      maxZoomLevel: 8,
      focalLatLng: const MapLatLng(20, 10),
    )..onTap = _onMapTap;
    _yearGuess = _defaultYear;
    _bootstrap();
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
      _userProgress =
          Hive.box<UserProgressModel>('userProgress').get('progress');

      final box = Hive.box<CardModel>(_boxName);
      final playable = box.values
          .map(_PlayableCard.tryFrom)
          .whereType<_PlayableCard>()
          .toList();
      if (playable.isEmpty) {
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
      setState(() {
        _deck = deck;
        _loading = false;
        _phase = _RoundPhase.guess;
      });
      _startRound();
    } catch (e) {
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
    _roundScore = 0;
    _zoomedToGuess = false;

    if (round.mode == _RoundMode.year && round.card.hasPins) {
      final pin = round.card.pins.first;
      _zoomPanBehavior.zoomLevel = 4;
      _zoomPanBehavior.focalLatLng = MapLatLng(pin.lat, pin.lng);
      _setMarkers(
        round.card.pins
            .map((p) => _MarkerSpec(lat: p.lat, lng: p.lng, isGuess: false))
            .toList(),
      );
    } else {
      _zoomPanBehavior.zoomLevel = _worldZoom;
      _zoomPanBehavior.focalLatLng = const MapLatLng(20, 10);
      _setMarkers(const []);
    }
  }

  void _setMarkers(List<_MarkerSpec> markers) {
    _markers = markers;
    _mapController.clearMarkers();
    for (var i = 0; i < markers.length; i++) {
      _mapController.insertMarker(i);
    }
  }

  void _onMapTap(Offset localPosition) {
    if (_phase != _RoundPhase.guess) return;
    if (_current.mode != _RoundMode.place) return;
    final latLng = _mapController.pixelToLatLng(localPosition);
    final firstTap = !_zoomedToGuess;
    setState(() {
      _guessLatLng = latLng;
      _setMarkers([
        _MarkerSpec(
          lat: latLng.latitude,
          lng: latLng.longitude,
          isGuess: true,
        ),
      ]);
      if (firstTap) {
        _zoomedToGuess = true;
        _zoomPanBehavior.zoomLevel = _placeDetailZoom;
        _zoomPanBehavior.focalLatLng = latLng;
      } else {
        // Keep detail zoom; gently re-center on the new pin.
        _zoomPanBehavior.focalLatLng = latLng;
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
        ...round.card.pins
            .map((p) => _MarkerSpec(lat: p.lat, lng: p.lng, isGuess: false)),
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
      _roundScore = score;
      _sessionScore += score;
      _roundScores.add(score);
      _phase = _RoundPhase.reveal;
    });
  }

  void _nextRound() {
    if (_roundIndex >= _deck.length - 1) {
      setState(() => _phase = _RoundPhase.summary);
      return;
    }
    setState(() {
      _roundIndex++;
      _phase = _RoundPhase.guess;
      _startRound();
    });
  }

  void _restart() {
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
      _roundScore = 0;
      _zoomedToGuess = false;
      _setMarkers(const []);
    });
    _bootstrap();
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
        SafeArea(child: _buildTopChrome()),
        SafeArea(child: _buildObjectiveCardOverlay()),
        if (_phase == _RoundPhase.reveal)
          SafeArea(child: _buildRevealOverlay()),
        SafeArea(child: _buildFloatConfirm()),
        Positioned(
          left: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          child: Text(
            '© OpenStreetMap',
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
      child: _chromeIconButton(
        icon: Icons.close,
        tooltip: 'Exit',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Top row: exit · year slider (when needed) · round progress.
  Widget _buildTopChrome() {
    final yearMode = _current.mode == _RoundMode.year;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _chromeIconButton(
                icon: Icons.close,
                tooltip: 'Exit',
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: yearMode
                    ? _buildCompactTimeline()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _phase == _RoundPhase.reveal
                              ? 'Round score: $_roundScore'
                              : 'Tap the map where this belongs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColorPalette.textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            shadows: const [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '${_roundIndex + 1}/${_deck.length}',
                  style: TextStyle(
                    color: AppColorPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (yearMode) ...[
            const SizedBox(height: 2),
            Text(
              _formatYear(_yearGuess).toLowerCase(),
              style: TextStyle(
                color: AppColorPalette.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTimeline() {
    final locked = _phase != _RoundPhase.guess;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: _yearGuess.toDouble().clamp(
              _minYear.toDouble(),
              _maxYear.toDouble(),
            ),
        min: _minYear.toDouble(),
        max: _maxYear.toDouble(),
        activeColor: AppColorPalette.color1,
        onChanged: locked
            ? null
            : (value) => setState(() => _yearGuess = value.round()),
      ),
    );
  }

  Widget _buildObjectiveCardOverlay() {
    final catalog = CardRepository.fromCardModel(_current.card.source);
    final cardHeight = _overlayCardWidth / CollectibleCardLayout.aspectRatio;
    // Sit under the top chrome so the card peeks onto the map.
    final topInset = _current.mode == _RoundMode.year ? 72.0 : 48.0;

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 10, top: topInset),
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

  Widget _buildMap() {
    return SfMaps(
      layers: [
        MapTileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          zoomPanBehavior: _zoomPanBehavior,
          controller: _mapController,
          initialMarkersCount: _markers.length,
          markerBuilder: (context, index) {
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
                color: marker.isGuess
                    ? Colors.redAccent
                    : AppColorPalette.success,
                size: marker.isGuess ? 32 : 28,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRevealOverlay() {
    final round = _current;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        child: Material(
          elevation: 4,
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (round.card.placeLabel != null)
                  Text(
                    round.card.placeLabel!,
                    style: TextStyle(
                      color: AppColorPalette.textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_geoResult != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Off by ${_formatDistance(_geoResult!.distanceKm)} · '
                    '+${_geoResult!.score}',
                    style: TextStyle(color: AppColorPalette.textSecondary),
                  ),
                ],
                if (_yearResult != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_formatYear(round.card.year!)} · you said '
                    '${_formatYear(_yearGuess)} · off by '
                    '${_yearResult!.deltaYears} yr · +${_yearResult!.score}',
                    style: TextStyle(color: AppColorPalette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatConfirm() {
    late final String label;
    late final IconData icon;
    late final VoidCallback? onPressed;
    if (_phase == _RoundPhase.reveal) {
      final last = _roundIndex >= _deck.length - 1;
      label = last ? 'Results' : 'Next';
      icon = last ? Icons.flag_outlined : Icons.arrow_forward;
      onPressed = _nextRound;
    } else if (_current.mode == _RoundMode.place) {
      label = 'Confirm';
      icon = Icons.check;
      onPressed = _guessLatLng == null ? null : _confirmGuess;
    } else {
      label = 'Confirm';
      icon = Icons.check;
      onPressed = _confirmGuess;
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: CustomFloatingActionButton(
          heroTag: 'chrono_atlas_action',
          label: label,
          icon: icon,
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _chromeIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColorPalette.textColor),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _chromeIconButton(
                icon: Icons.close,
                tooltip: 'Exit',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Session complete',
                  style: TextStyle(
                    color: AppColorPalette.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total: $_sessionScore',
            style: TextStyle(
              color: AppColorPalette.color1,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _deck.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final round = _deck[i];
                final score = i < _roundScores.length ? _roundScores[i] : 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: round.card.imageIndex != null
                      ? MotivationIconWidget(
                          imageIndex: round.card.imageIndex!,
                          size: 36,
                        )
                      : null,
                  title: Text(
                    round.card.title,
                    style: TextStyle(color: AppColorPalette.textColor),
                  ),
                  subtitle: Text(
                    round.mode == _RoundMode.place ? 'Place' : 'Year',
                    style: TextStyle(color: AppColorPalette.textSecondary),
                  ),
                  trailing: Text(
                    '+$score',
                    style: TextStyle(
                      color: AppColorPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: _restart,
            child: const Text('Play again'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to games'),
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

class _TapZoomPanBehavior extends MapZoomPanBehavior {
  _TapZoomPanBehavior({
    super.enablePanning,
    super.enablePinching,
    super.zoomLevel,
    super.minZoomLevel,
    super.maxZoomLevel,
    super.focalLatLng,
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

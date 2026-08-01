import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/chrono_atlas_scoring.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/widgets/game_icon_widget.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

enum _RoundPhase { place, year, reveal, summary }

class ChronoAtlasScreen extends StatefulWidget {
  const ChronoAtlasScreen({super.key, this.roundsPerSession = 5});

  final int roundsPerSession;

  @override
  State<ChronoAtlasScreen> createState() => _ChronoAtlasScreenState();
}

class _ChronoAtlasScreenState extends State<ChronoAtlasScreen> {
  static const String _boxName = 'motivationItems';

  bool _loading = true;
  String? _error;
  List<_PlayableCard> _deck = const [];
  int _roundIndex = 0;
  int _sessionScore = 0;
  _RoundPhase _phase = _RoundPhase.place;

  MapLatLng? _guessLatLng;
  late final MapTileLayerController _mapController;
  late final _TapZoomPanBehavior _zoomPanBehavior;

  late final TextEditingController _yearController;
  int? _yearGuess;

  ChronoAtlasGeoResult? _geoResult;
  ChronoAtlasYearResult? _yearResult;
  int _roundScore = 0;
  final List<int> _roundScores = [];

  /// Markers: index 0 = guess (optional), then answer pins.
  int _markerCount = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapTileLayerController();
    _zoomPanBehavior = _TapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomLevel: 1.5,
      minZoomLevel: 1,
      maxZoomLevel: 8,
      focalLatLng: const MapLatLng(20, 10),
    )..onTap = _onMapTap;
    _yearController = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await MotivationSeedService.ensureSeeded();
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<CardModel>(_boxName);
      }
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
      playable.shuffle(math.Random());
      final take = math.min(widget.roundsPerSession, playable.length);
      setState(() {
        _deck = playable.take(take).toList();
        _loading = false;
        _phase = _deck.first.hasPins ? _RoundPhase.place : _RoundPhase.year;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load Chrono Atlas: $e';
      });
    }
  }

  _PlayableCard get _current => _deck[_roundIndex];

  void _onMapTap(Offset localPosition) {
    if (_phase != _RoundPhase.place) return;
    final latLng = _mapController.pixelToLatLng(localPosition);
    setState(() {
      _guessLatLng = latLng;
      _mapController.clearMarkers();
      _markerCount = 1;
      _mapController.insertMarker(0);
    });
  }

  void _confirmPlace() {
    if (_guessLatLng == null) return;
    if (_current.hasYear) {
      setState(() => _phase = _RoundPhase.year);
    } else {
      _reveal();
    }
  }

  void _confirmYear() {
    final parsed = int.tryParse(_yearController.text.trim());
    if (parsed == null) return;
    _yearGuess = parsed;
    _reveal();
  }

  void _reveal() {
    ChronoAtlasGeoResult? geo;
    ChronoAtlasYearResult? year;
    var score = 0;

    if (_current.hasPins && _guessLatLng != null) {
      geo = ChronoAtlasScoring.scoreGeo(
        guessLat: _guessLatLng!.latitude,
        guessLng: _guessLatLng!.longitude,
        pins: _current.pins,
      );
      score += geo.score;
    }
    if (_current.hasYear && _yearGuess != null) {
      year = ChronoAtlasScoring.scoreYear(
        guess: _yearGuess!,
        answer: _current.year!,
      );
      score += year.score;
    }

    if (_current.hasPins) {
      _mapController.clearMarkers();
      _markerCount = (_guessLatLng != null ? 1 : 0) + _current.pins.length;
      for (var i = 0; i < _markerCount; i++) {
        _mapController.insertMarker(i);
      }
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
      _guessLatLng = null;
      _yearGuess = null;
      _yearController.clear();
      _geoResult = null;
      _yearResult = null;
      _roundScore = 0;
      _markerCount = 0;
      _mapController.clearMarkers();
      _zoomPanBehavior.zoomLevel = 1.5;
      _zoomPanBehavior.focalLatLng = const MapLatLng(20, 10);
      _phase = _current.hasPins ? _RoundPhase.place : _RoundPhase.year;
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
      _yearGuess = null;
      _yearController.clear();
      _geoResult = null;
      _yearResult = null;
      _roundScore = 0;
      _markerCount = 0;
      _mapController.clearMarkers();
    });
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorPalette.background,
      appBar: AppBar(
        title: const Text('Chrono Atlas'),
        backgroundColor: AppColorPalette.backgroundSurface,
        foregroundColor: AppColorPalette.textColor,
        actions: [
          if (!_loading && _error == null && _phase != _RoundPhase.summary)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_roundIndex + 1}/${_deck.length} · $_sessionScore',
                  style: TextStyle(
                    color: AppColorPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_phase == _RoundPhase.summary) {
      return _buildSummary();
    }
    return Column(
      children: [
        _buildPromptHeader(),
        Expanded(child: _buildPhaseBody()),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildPromptHeader() {
    final card = _current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColorPalette.backgroundSurface,
      child: Row(
        children: [
          if (card.imageIndex != null)
            MotivationIconWidget(imageIndex: card.imageIndex!, size: 48)
          else
            Icon(Icons.public, color: AppColorPalette.color1, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: TextStyle(
                    color: AppColorPalette.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  card.category,
                  style: TextStyle(
                    color: AppColorPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _phaseHint(),
                  style: TextStyle(
                    color: AppColorPalette.color1,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _phaseHint() {
    switch (_phase) {
      case _RoundPhase.place:
        return 'Tap the map where this belongs';
      case _RoundPhase.year:
        return 'Guess the ${_yearKindLabel(_current.yearKind ?? 'year')}';
      case _RoundPhase.reveal:
        return 'Round score: $_roundScore';
      case _RoundPhase.summary:
        return '';
    }
  }

  Widget _buildPhaseBody() {
    switch (_phase) {
      case _RoundPhase.place:
      case _RoundPhase.reveal:
        return _buildMap();
      case _RoundPhase.year:
        return _buildYearInput();
      case _RoundPhase.summary:
        return _buildSummary();
    }
  }

  Widget _buildMap() {
    final showAnswers = _phase == _RoundPhase.reveal;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SfMaps(
                layers: [
                  MapTileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    zoomPanBehavior: _zoomPanBehavior,
                    controller: _mapController,
                    initialMarkersCount: _markerCount,
                    markerBuilder: (context, index) {
                      if (_guessLatLng != null && index == 0) {
                        return MapMarker(
                          latitude: _guessLatLng!.latitude,
                          longitude: _guessLatLng!.longitude,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                        );
                      }
                      final pinIndex =
                          _guessLatLng != null ? index - 1 : index;
                      if (pinIndex < 0 || pinIndex >= _current.pins.length) {
                        return const MapMarker(
                          latitude: 0,
                          longitude: 0,
                          child: SizedBox.shrink(),
                        );
                      }
                      final pin = _current.pins[pinIndex];
                      return MapMarker(
                        latitude: pin.lat,
                        longitude: pin.lng,
                        child: Icon(
                          Icons.flag,
                          color: AppColorPalette.success,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Positioned(
                left: 8,
                bottom: 8,
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
          ),
        ),
        if (showAnswers) _buildRevealPanel(),
      ],
    );
  }

  Widget _buildRevealPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColorPalette.backgroundSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_current.placeLabel != null)
            Text(
              _current.placeLabel!,
              style: TextStyle(
                color: AppColorPalette.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (_geoResult != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_geoResult!.distanceKm.round()} km · +${_geoResult!.score}',
              style: TextStyle(color: AppColorPalette.textSecondary),
            ),
          ],
          if (_current.hasYear) ...[
            const SizedBox(height: 8),
            Text(
              'Year: ${_formatYear(_current.year!)}'
              '${_yearGuess != null ? ' (you: ${_formatYear(_yearGuess!)})' : ''}'
              '${_yearResult != null ? ' · +${_yearResult!.score}' : ''}',
              style: TextStyle(color: AppColorPalette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYearInput() {
    final kind = _current.yearKind ?? 'year';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What ${_yearKindLabel(kind)}?',
            style: TextStyle(
              color: AppColorPalette.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use negative numbers for BC (e.g. -470).',
            style: TextStyle(color: AppColorPalette.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _yearController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
            ],
            style: TextStyle(color: AppColorPalette.textColor, fontSize: 22),
            decoration: InputDecoration(
              labelText: 'Year',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: AppColorPalette.backgroundSurface,
            ),
            onSubmitted: (_) => _confirmYear(),
          ),
        ],
      ),
    );
  }

  String _yearKindLabel(String kind) {
    switch (kind) {
      case 'birth':
        return 'birth year';
      case 'invented':
        return 'invention / publish year';
      case 'described':
        return 'scientific description year';
      default:
        return 'year';
    }
  }

  Widget _buildBottomBar() {
    if (_phase == _RoundPhase.summary) return const SizedBox.shrink();
    late final String label;
    late final VoidCallback? onPressed;
    switch (_phase) {
      case _RoundPhase.place:
        label = 'Confirm place';
        onPressed = _guessLatLng == null ? null : _confirmPlace;
        break;
      case _RoundPhase.year:
        label = 'Confirm year';
        onPressed = _confirmYear;
        break;
      case _RoundPhase.reveal:
        label = _roundIndex >= _deck.length - 1 ? 'See results' : 'Next';
        onPressed = _nextRound;
        break;
      case _RoundPhase.summary:
        label = '';
        onPressed = null;
        break;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session complete',
            style: TextStyle(
              color: AppColorPalette.textColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
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
                final card = _deck[i];
                final score = i < _roundScores.length ? _roundScores[i] : 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: card.imageIndex != null
                      ? MotivationIconWidget(
                          imageIndex: card.imageIndex!,
                          size: 36,
                        )
                      : null,
                  title: Text(
                    card.title,
                    style: TextStyle(color: AppColorPalette.textColor),
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
    if (year < 0) return '${year.abs()} BC';
    return '$year';
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

class _PlayableCard {
  const _PlayableCard({
    required this.title,
    required this.category,
    required this.pins,
    this.year,
    this.yearKind,
    this.placeLabel,
    this.imageIndex,
  });

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

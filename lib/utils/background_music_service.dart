import 'package:audioplayers/audioplayers.dart';
import 'lofi_service.dart';
import '../models/lofi_track.dart';

class BackgroundMusicService {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  LofiTrack? _currentTrack;
  bool _isPlaying = false;
  bool _isLooping = false;
  double _volume = 0.7;
  List<LofiTrack> _playlist = [];
  int _currentTrackIndex = 0;

  bool get isPlaying => _isPlaying;
  LofiTrack? get currentTrack => _currentTrack;
  double get volume => _volume;
  bool get isLooping => _isLooping;

  Future<void> initialize() async {
    try {
      _playlist = await LofiService.getAllTracks();
      _setupAudioPlayerListeners();
    } catch (e) {
      print('Failed to initialize background music service: $e');
    }
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_isLooping) {
        _playCurrentTrack();
      } else {
        _playNextTrack();
      }
    });
  }

  Future<void> playRandomTrack() async {
    if (_playlist.isEmpty) {
      await _refreshPlaylist();
      if (_playlist.isEmpty) return;
    }

    _playlist.shuffle();
    _currentTrackIndex = 0;
    _currentTrack = _playlist[_currentTrackIndex];
    await _playCurrentTrack();
  }

  Future<void> playRandomTrackFromFilenames(Set<String> allowedFilenames) async {
    if (allowedFilenames.isEmpty) return;
    if (_playlist.isEmpty) {
      await _refreshPlaylist();
      if (_playlist.isEmpty) return;
    }

    final filtered = _playlist
        .where((track) => allowedFilenames.contains(track.filename))
        .toList();
    if (filtered.isEmpty) return;
    filtered.shuffle();
    _currentTrack = filtered.first;
    final index = _playlist.indexWhere((t) => t.id == _currentTrack!.id);
    _currentTrackIndex = index >= 0 ? index : 0;
    await _playCurrentTrack();
  }

  bool isCurrentTrackAllowed(Set<String> allowedFilenames) {
    final current = _currentTrack;
    if (current == null) return false;
    return allowedFilenames.contains(current.filename);
  }

  Future<void> playTrackById(int trackId) async {
    final track = await LofiService.getTrackById(trackId);
    if (track != null) {
      _currentTrack = track;
      final index = _playlist.indexWhere((t) => t.id == trackId);
      if (index >= 0) {
        _currentTrackIndex = index;
      }
      await _playCurrentTrack();
    }
  }

  Future<void> _playCurrentTrack() async {
    if (_currentTrack == null) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('lofi/${_currentTrack!.filename}'));
      await _audioPlayer.setVolume(_volume);
      _isPlaying = true;
    } catch (e) {
      print('Failed to play track ${_currentTrack!.filename}: $e');
      // Try to play next track if current fails
      await _playNextTrack();
    }
  }

  Future<void> _playNextTrack() async {
    if (_playlist.isEmpty) return;

    _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
    _currentTrack = _playlist[_currentTrackIndex];
    await _playCurrentTrack();
  }

  Future<void> playPreviousTrack() async {
    if (_playlist.isEmpty) return;

    _currentTrackIndex = _currentTrackIndex > 0
        ? _currentTrackIndex - 1
        : _playlist.length - 1;
    _currentTrack = _playlist[_currentTrackIndex];
    await _playCurrentTrack();
  }

  Future<void> pause() async {
    print('[BG_SERVICE] pause() called');
    print('[BG_SERVICE] Before pause - isPlaying: $_isPlaying');
    await _audioPlayer.pause();
    _isPlaying = false;
    print('[BG_SERVICE] After pause - isPlaying: $_isPlaying');
  }

  Future<void> resume() async {
    print('[BG_SERVICE] resume() called');
    print('[BG_SERVICE] Before resume - isPlaying: $_isPlaying');
    await _audioPlayer.resume();
    _isPlaying = true;
    print('[BG_SERVICE] After resume - isPlaying: $_isPlaying');
  }

  /// Resumes after [pause], or replays from the start after [stop]/session end.
  Future<void> ensurePlaying() async {
    if (_currentTrack == null) {
      await playRandomTrack();
      return;
    }
    if (_isPlaying) return;

    final state = _audioPlayer.state;
    if (state == PlayerState.paused) {
      await resume();
      return;
    }

    await _playCurrentTrack();
  }

  Future<void> stop() async {
    print('[BG_SERVICE] stop() called');
    await _audioPlayer.stop();
    _isPlaying = false;
    print('[BG_SERVICE] After stop - isPlaying: $_isPlaying');
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
  }

  void setLooping(bool loop) {
    _isLooping = loop;
  }

  Future<void> _refreshPlaylist() async {
    try {
      _playlist = await LofiService.getAllTracks();
    } catch (e) {
      print('Failed to refresh playlist: $e');
    }
  }

  Future<List<LofiTrack>> getPlaylistForDuration(
    Duration targetDuration,
  ) async {
    final tracks = await LofiService.getAllTracks();
    final selectedTracks = <LofiTrack>[];
    Duration totalDuration = Duration.zero;

    // Sort by duration to optimize selection
    tracks.sort(
      (a, b) =>
          _parseDuration(a.duration).compareTo(_parseDuration(b.duration)),
    );

    for (final track in tracks) {
      final trackDuration = _parseDuration(track.duration);
      if (totalDuration + trackDuration <= targetDuration) {
        selectedTracks.add(track);
        totalDuration += trackDuration;
      }
      if (totalDuration >= targetDuration) break;
    }

    return selectedTracks;
  }

  Duration _parseDuration(String durationString) {
    final parts = durationString.split(':');
    if (parts.length != 2) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;

    return Duration(minutes: minutes, seconds: seconds);
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

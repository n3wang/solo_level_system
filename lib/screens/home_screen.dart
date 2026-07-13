import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/widgets/pomodoro/project_selector_widget.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/reward_model.dart';

import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:solo_level_system/utils/database_utils.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/sound_effects_service.dart';
import 'package:solo_level_system/utils/audio_utils.dart';
import 'package:solo_level_system/utils/notification_service.dart';
import 'package:solo_level_system/utils/timer_controller.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/session_reward_service.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/widgets/common/session_loot_dialog.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/room_model.dart';

// New imports for refactored widgets and constants
import 'package:solo_level_system/utils/pomodoro_sizing.dart';
import 'package:solo_level_system/widgets/pomodoro/compact_music_widget.dart';
import 'package:solo_level_system/widgets/pomodoro/session_squares_widget.dart';
import 'package:solo_level_system/widgets/pomodoro/session_recording_preview.dart';
import 'package:solo_level_system/screens/room_management_screen.dart';
import 'package:solo_level_system/screens/projects_management_screen.dart';
import 'package:solo_level_system/utils/room_management_seed_service.dart';
import 'package:solo_level_system/utils/unlock_service.dart';
import 'package:solo_level_system/utils/project_seed_service.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/widgets/pomodoro/long_break_modal.dart';
import 'package:solo_level_system/utils/lofi_service.dart';
import 'package:solo_level_system/models/lofi_track.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const HomeScreen({super.key, this.onSettingsChanged});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int workMinutes = 25;
  int breakMinutes = 5;
  int remainingSeconds = 1500;
  bool isRunning = false;
  bool onBreak = false;
  bool showPlayer = false;
  String? audioPath;
  EnhancedAudioModel? recordedAudio;
  String logStateMessage = "State: ";
  int countCompletedToday = 0;
  bool canSubmitLog = false;
  String? imagePath;
  String? currentlyPlayingTrack;
  ConfigModel? config;
  UserSettingsModel? userSettings;
  int lastTrackIndex = 0;
  List<ProjectModel> projects = [];
  ProjectModel? selectedProject;
  List<RoomModel> rooms = [];
  RoomModel? selectedRoom;
  bool _isRoomQuickPickerOpen = false;
  final Map<String, String> _roomQuickVisualPathById = {};

  // Progress system state
  UserProgressModel? userProgress;

  // Timer-related state
  Timer? timer;
  DateTime? sessionStartTime;
  final Random _random = Random();
  Timer? _roomPhraseTimer;
  List<String> _roomPhrases = [];
  List<RoomVisualConfig> _roomVisuals = [];
  List<String> _roomSelectedTracks = [];
  int _currentRoomVisualIndex = 0;
  String? _currentRoomPhrase;

  final _bgPlayer = ap.AudioPlayer();
  final _backgroundMusicService = BackgroundMusicService();
  final _soundEffectsService = SoundEffectsService();
  final _notificationService = NotificationService();
  final _timerController = TimerController();

  static const List<String> _breakPhaseMessages = [
    'Break time',
    'Rest a bit',
    'Stretch & breathe',
    'Step away for a minute',
    'Eyes off the screen',
    'Hydrate',
    'Reset your mind',
    'Short pause earned',
  ];

  static const List<String> _workPhaseMessages = [
    'Focus time',
    'Back to work',
    'Deep work',
    'Let\'s go',
    'One more block',
    'Heads down',
    'Make it count',
    'Time to build',
  ];

  void _showSessionPhaseSnack(List<String> messages) {
    if (!mounted) return;
    showAppSnackMessage(context, messages: messages, random: _random);
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Latest completed focus session date (Hive, then progress fallback).
  DateTime? _lastCompletedSessionDate() {
    DateTime? latest;
    if (Hive.isBoxOpen('pomodoros')) {
      final box = Hive.box<PomodoroModel>('pomodoros');
      for (final session in box.values) {
        if (latest == null || session.startTime.isAfter(latest)) {
          latest = session.startTime;
        }
      }
    }
    final progressDate = userProgress?.lastSessionDate;
    if (progressDate != null &&
        (latest == null || progressDate.isAfter(latest))) {
      latest = progressDate;
    }
    return latest;
  }

  /// Clears under-timer squares when a new calendar day begins.
  Future<void> _flushSessionSquaresIfNewDay() async {
    final now = DateTime.now();
    final last = _lastCompletedSessionDate();
    if (last != null && _isSameCalendarDay(last, now)) return;

    final count = await getTodayCompletedSessions();
    if (!mounted) return;
    if (countCompletedToday == count) return;
    setState(() => countCompletedToday = count);
  }

  void _onTimerStateChanged() {
    final wasRunning = isRunning;
    final previousTrack = currentlyPlayingTrack;
    setState(() {
      // Update UI when timer state changes
      remainingSeconds = _timerController.remainingSeconds;
      isRunning = _timerController.isRunning;
      onBreak = _timerController.onBreak;
      currentlyPlayingTrack = _timerController.getCurrentTrackTitle();

      // If work session completed (not running, not on break, timer at 0)
      if (!_timerController.isRunning &&
          !_timerController.onBreak &&
          _timerController.remainingSeconds == 0) {
        canSubmitLog = true;
        logStateMessage = "State: Finished – Submit Log";
      }

      // Hide room quick rail when a session starts.
      if (!wasRunning && _timerController.isRunning) {
        _isRoomQuickPickerOpen = false;
      }
    });

    if (previousTrack != null &&
        currentlyPlayingTrack != null &&
        previousTrack != currentlyPlayingTrack) {
      _advanceRoomVisual();
    }

    if (!wasRunning && _timerController.isRunning) {
      _startRoomPhraseRotation();
    } else if (wasRunning && !_timerController.isRunning) {
      _stopRoomPhraseRotation(clearCurrent: false);
    }
  }

  Future<void> _loadSelectedRoomPhrases() async {
    final roomKey = selectedRoom?.id ?? '__random__';
    if (!Hive.isBoxOpen('roomManagement')) {
      await Hive.openBox('roomManagement');
    }

    final box = Hive.box('roomManagement');
    final raw = box.get(roomKey);

    List<String> phrases = [];
    List<RoomVisualConfig> visuals = [];
    List<String> selectedTracks = [];
    if (raw is Map) {
      final model = RoomManagementModel.fromMap(raw);
      phrases = model.phrases;
      visuals = await _sanitizeRoomVisuals(model.selectedVisuals);
      selectedTracks = model.selectedTracks;
    }

    if (!mounted) return;
    setState(() {
      _roomPhrases = phrases;
      _roomVisuals = visuals;
      _roomSelectedTracks = selectedTracks;
      if (_roomVisuals.isEmpty) {
        _currentRoomVisualIndex = 0;
      } else if (_currentRoomVisualIndex >= _roomVisuals.length) {
        _currentRoomVisualIndex = 0;
      }
      if (_roomPhrases.isEmpty) {
        _currentRoomPhrase = null;
      } else if (_currentRoomPhrase == null ||
          !_roomPhrases.contains(_currentRoomPhrase)) {
        _currentRoomPhrase = _roomPhrases[_random.nextInt(_roomPhrases.length)];
      }
    });

    if (_timerController.isRunning) {
      _startRoomPhraseRotation();
    }
    await _enforceRoomTrackRestriction();
  }

  Future<void> _loadRoomQuickPickerVisuals() async {
    if (!Hive.isBoxOpen('roomManagement')) {
      await Hive.openBox('roomManagement');
    }
    final box = Hive.box('roomManagement');
    final nextMap = <String, String>{};
    final rawMap = box.toMap();
    for (final entry in rawMap.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      final model = RoomManagementModel.fromMap(value);
      final visuals = await _sanitizeRoomVisuals(model.selectedVisuals);
      if (visuals.isNotEmpty) {
        nextMap[key] = visuals.first.path;
      }
    }
    if (!mounted) return;
    setState(() {
      _roomQuickVisualPathById
        ..clear()
        ..addAll(nextMap);
    });
  }

  List<RoomModel> get _quickPickerRooms {
    final activeRooms = rooms.where((room) => room.isActive).toList();
    if (activeRooms.length <= 5) return activeRooms;
    final shortlist = activeRooms.take(5).toList();
    final selected = selectedRoom;
    if (selected != null &&
        selected.isActive &&
        !shortlist.any((room) => room.id == selected.id)) {
      shortlist[shortlist.length - 1] = selected;
    }
    return shortlist;
  }

  ImageProvider? _roomQuickImageProvider(RoomModel room) {
    if (room.iconAssetPath != null && room.iconAssetPath!.isNotEmpty) {
      return AssetImage(room.iconAssetPath!);
    }
    final path = _roomQuickVisualPathById[room.id];
    if (path != null && path.isNotEmpty) {
      if (_isAssetReference(path)) {
        return AssetImage(path.substring('asset:'.length));
      }
      if (_isDataUriReference(path)) {
        return MemoryImage(_bytesFromDataUri(path));
      }
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return null;
  }

  Future<void> _selectRoomFromQuickPicker(RoomModel room) async {
    if (!mounted) return;
    setState(() {
      selectedRoom = room;
      _isRoomQuickPickerOpen = false;
      _currentRoomVisualIndex = 0;
    });
    await _loadSelectedRoomPhrases();
  }

  Future<void> _clearRoomFromQuickPicker() async {
    if (!mounted) return;
    setState(() {
      selectedRoom = null;
      _isRoomQuickPickerOpen = false;
      _roomVisuals = [];
      _currentRoomVisualIndex = 0;
    });
    await _loadSelectedRoomPhrases();
  }

  Widget _buildRoomQuickPickerRail() {
    final items = _quickPickerRooms;
    final isOpen = _isRoomQuickPickerOpen && items.isNotEmpty;
    final showNoRoomAction = selectedRoom != null;
    final totalCount = items.length + (showNoRoomAction ? 1 : 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: isOpen ? ((totalCount * 42) + ((totalCount - 1) * 8) + 12) : 0,
      height: 40,
      child: ClipRect(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isOpen ? 1 : 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  if (showNoRoomAction) ...[
                    _buildNoRoomQuickPickerItem(),
                    if (items.isNotEmpty) const SizedBox(width: 8),
                  ],
                  for (int index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    _buildRoomQuickPickerItem(items[index]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoRoomQuickPickerItem() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _clearRoomFromQuickPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.42),
            width: 1.1,
          ),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        ),
        child: Icon(
          Icons.meeting_room_outlined,
          size: 18,
          color: scheme.onSurface.withValues(alpha: 0.76),
        ),
      ),
    );
  }

  Widget _buildRoomQuickPickerItem(RoomModel room) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selectedRoom?.id == room.id;
    final imageProvider = _roomQuickImageProvider(room);
    return GestureDetector(
      onTap: () async => _selectRoomFromQuickPicker(room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.42),
            width: isSelected ? 1.8 : 1.1,
          ),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: imageProvider == null
            ? Icon(
                Icons.meeting_room_outlined,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.76),
              )
            : null,
      ),
    );
  }

  Future<void> _handleRoomFabTap() async {
    if (_isRoomQuickPickerOpen) {
      await _openRoomManagement();
      return;
    }
    if (_quickPickerRooms.isEmpty) {
      await _openRoomManagement();
      return;
    }
    if (!mounted) return;
    setState(() {
      _isRoomQuickPickerOpen = true;
    });
  }

  Widget _buildRoomFabWithPicker() {
    final items = _quickPickerRooms;
    final isOpen = _isRoomQuickPickerOpen && items.isNotEmpty;
    final totalCount = items.length + (selectedRoom != null ? 1 : 0);
    final railWidth = isOpen && totalCount > 0
        ? ((totalCount * 42) + ((totalCount - 1) * 8) + 12)
        : 0.0;
    const double roomFabSize = 40;
    const double railStartOffset =
        52; // Keep expanded icons clearly to the right.

    return SizedBox(
      width: roomFabSize + railWidth + 16,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: railStartOffset,
            top: 1,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: isOpen ? Offset.zero : const Offset(-0.35, 0),
              child: _buildRoomQuickPickerRail(),
            ),
          ),
          Positioned(
            left: 0,
            top: 1,
            child: GestureDetector(
              onTap: _handleRoomFabTap,
              child: Tooltip(
                message: isOpen ? 'Open room management' : 'Open quick rooms',
                child: Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.home_work_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Project + room FABs: slide in from the left when the timer is paused,
  /// slide back out when a pomodoro is running.
  Widget _buildSideActionFabs() {
    final show = !_timerController.isRunning;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: show ? Offset.zero : const Offset(-1.35, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: show ? 1 : 0,
        child: IgnorePointer(
          ignoring: !show,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton.small(
                heroTag: 'project-management-fab',
                tooltip: 'Open project management',
                elevation: 0,
                hoverElevation: 0,
                focusElevation: 0,
                highlightElevation: 0,
                onPressed: _openProjectManagement,
                child: const Icon(Icons.folder_open_outlined),
              ),
              const SizedBox(height: 8),
              _buildRoomFabWithPicker(),
            ],
          ),
        ),
      ),
    );
  }

  void _advanceRoomVisual() {
    if (selectedRoom == null || _roomVisuals.length <= 1 || !mounted) return;
    setState(() {
      _currentRoomVisualIndex =
          (_currentRoomVisualIndex + 1) % _roomVisuals.length;
    });
  }

  bool _isAssetReference(String path) => path.startsWith('asset:');
  bool _isDataUriReference(String path) => path.startsWith('data:');

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<RoomVisualConfig>> _sanitizeRoomVisuals(
    List<RoomVisualConfig> visuals,
  ) async {
    final valid = <RoomVisualConfig>[];
    for (final visual in visuals) {
      final path = visual.path.trim();
      if (path.isEmpty) continue;
      if (_isAssetReference(path)) {
        final resolved = path.substring('asset:'.length);
        if (await _assetExists(resolved)) {
          valid.add(visual);
        }
        continue;
      }
      if (_isDataUriReference(path)) {
        valid.add(visual);
        continue;
      }
      final file = File(path);
      if (file.existsSync()) {
        valid.add(visual);
      }
    }
    return valid;
  }

  RoomVisualConfig? _currentRoomVisual() {
    if (selectedRoom == null || _roomVisuals.isEmpty) return null;
    return _roomVisuals[_currentRoomVisualIndex % _roomVisuals.length];
  }

  Widget? _currentPomodoroMediaWidget({required bool playing}) {
    final visual = _currentRoomVisual();
    if (visual != null) {
      if (visual.isGif) {
        return _HomeSpeedControlledGif(
          sourcePath: visual.path,
          isAssetReference: _isAssetReference(visual.path),
          speed: visual.gifSpeed,
          playing: playing,
          fit: BoxFit.cover,
          errorChild: Container(
            color: AppColorPalette.success.withValues(alpha: 0.1),
          ),
        );
      }
      if (_isAssetReference(visual.path)) {
        return Image.asset(
          visual.path.substring('asset:'.length),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      if (_isDataUriReference(visual.path)) {
        return Image.memory(
          _bytesFromDataUri(visual.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return Image.file(
        File(visual.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    final albumImagePath = _backgroundMusicService.currentTrack?.albumImagePath;
    if (albumImagePath != null) {
      final img = Image.asset(
        albumImagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      if (albumImagePath.toLowerCase().endsWith('.gif')) {
        return TickerMode(enabled: playing, child: img);
      }
      return img;
    }
    return null;
  }

  Uint8List _bytesFromDataUri(String dataUri) {
    final comma = dataUri.indexOf(',');
    if (comma < 0 || comma >= dataUri.length - 1) {
      return Uint8List(0);
    }
    return base64Decode(dataUri.substring(comma + 1));
  }

  void _startRoomPhraseRotation() {
    _roomPhraseTimer?.cancel();
    if (_roomPhrases.isEmpty || !_timerController.isRunning) return;

    if (_currentRoomPhrase == null) {
      setState(() {
        _currentRoomPhrase = _roomPhrases[_random.nextInt(_roomPhrases.length)];
      });
    }

    _roomPhraseTimer = Timer.periodic(const Duration(seconds: 24), (_) {
      if (!_timerController.isRunning || _roomPhrases.isEmpty || !mounted) {
        return;
      }

      setState(() {
        if (_roomPhrases.length == 1) {
          _currentRoomPhrase = _roomPhrases.first;
        } else {
          String next = _currentRoomPhrase ?? _roomPhrases.first;
          while (next == _currentRoomPhrase) {
            next = _roomPhrases[_random.nextInt(_roomPhrases.length)];
          }
          _currentRoomPhrase = next;
        }
      });
    });
  }

  void _stopRoomPhraseRotation({bool clearCurrent = true}) {
    _roomPhraseTimer?.cancel();
    _roomPhraseTimer = null;
    if (clearCurrent && mounted) {
      setState(() {
        _currentRoomPhrase = null;
      });
    }
  }

  bool get _hasCompletedSessionToday => countCompletedToday > 0;

  String? _timerHelpText() {
    if (_hasCompletedSessionToday) return null;
    if (isRunning) {
      return onBreak ? 'Break Time - Tap to Stop' : 'Focus Time - Tap to Stop';
    }
    if (canSubmitLog) {
      if (recordedAudio != null) {
        return 'Session complete • Preview your note • Tap timer to submit';
      }
      return 'Session Complete - Tap to Submit!';
    }
    return 'Tap to Start • ↑ Finish • ↓ Reset';
  }

  String? _roomPhraseForOverlay() {
    if (!_hasCompletedSessionToday) return null;
    if (_currentRoomPhrase != null && _currentRoomPhrase!.trim().isNotEmpty) {
      return _currentRoomPhrase!;
    }
    if (_roomPhrases.isNotEmpty) {
      return _roomPhrases.first;
    }
    return null;
  }

  Widget _buildTimerOverlayText() {
    final scheme = Theme.of(context).colorScheme;
    final phraseText = _roomPhraseForOverlay();
    final text = phraseText ?? _timerHelpText();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      style: TextStyle(
        fontSize: AppColorPalette.fontSizeXSmall,
        color: scheme.onPrimary,
        fontStyle: phraseText == null ? FontStyle.italic : FontStyle.normal,
        fontWeight: phraseText == null ? FontWeight.normal : FontWeight.w600,
        shadows: [
          Shadow(
            blurRadius: 5.0,
            color: scheme.shadow,
            offset: Offset(1.0, 1.0),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSelectedProjectOverlayText() {
    final scheme = Theme.of(context).colorScheme;
    final project = selectedProject;
    if (project == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        '${project.name} ${project.workDurationMinutes}-${project.breakDurationMinutes}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: AppColorPalette.fontSizeXSmall,
          color: scheme.onPrimary,
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(
              blurRadius: 5.0,
              color: scheme.shadow,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRoomOverlayText() {
    final scheme = Theme.of(context).colorScheme;
    final room = selectedRoom;
    if (room == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text(
        room.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: AppColorPalette.fontSizeXSmall,
          color: scheme.onPrimary,
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(
              blurRadius: 5.0,
              color: scheme.shadow,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTimerText() {
    final scheme = Theme.of(context).colorScheme;
    final bool isUrgencyWindow =
        _timerController.isRunning &&
        remainingSeconds > 0 &&
        remainingSeconds <= 30;
    final double amplitude = remainingSeconds <= 10 ? 3.2 : 2.0;
    final double targetOffset = isUrgencyWindow
        ? (remainingSeconds.isEven ? -amplitude : amplitude)
        : 0.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'timer-shake-${_timerController.isRunning}-${_timerController.onBreak}-$remainingSeconds',
      ),
      tween: Tween(begin: 0, end: targetOffset),
      duration: Duration(milliseconds: remainingSeconds <= 10 ? 120 : 170),
      curve: Curves.easeOutCubic,
      builder: (context, dx, child) {
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Text(
        formatTime(remainingSeconds),
        style: TextStyle(
          fontSize: PomodoroSizing.getTimerFontSize(context),
          fontWeight: FontWeight.bold,
          color: scheme.onPrimary,
          shadows: [
            Shadow(
              blurRadius: 10.0,
              color: scheme.shadow,
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playLofi() async {
    print('[MUSIC] _playLofi() called');
    if (_backgroundMusicService.isPlaying) {
      print('[MUSIC] Music is already playing, stopping it first');
      await _backgroundMusicService.stop();
    }
    if (!_timerController.allowMusic) {
      print('[MUSIC] Timer controller says music not allowed');
      return;
    }

    // Check user settings for audio control
    if (!_timerController.onBreak &&
        !(userSettings?.playAudioDuringWork ?? true)) {
      // Don't play music during work sessions if disabled
      print(
        '[MUSIC] Not playing - work session and playAudioDuringWork is disabled',
      );
      return;
    }
    if (_timerController.onBreak &&
        !(userSettings?.playAudioDuringBreaks ?? false)) {
      // Don't play music during break sessions if disabled
      print(
        '[MUSIC] Not playing - break session and playAudioDuringBreaks is disabled',
      );
      return;
    }

    try {
      // Set looping based on config
      _backgroundMusicService.setLooping(config?.playAudioOnRepeat ?? false);
      print(
        '[MUSIC] Playing random track, looping: ${config?.playAudioOnRepeat ?? false}',
      );

      final allowed = _allowedRoomTrackFilenames();
      if (selectedRoom != null) {
        if (allowed.isEmpty) {
          await _backgroundMusicService.playRandomTrack();
        } else {
          await _backgroundMusicService.playRandomTrackFromFilenames(allowed);
        }
      } else {
        await _backgroundMusicService.playRandomTrack();
      }

      // Update the current track display
      final previousTrack = currentlyPlayingTrack;
      setState(() {
        final track = _backgroundMusicService.currentTrack;
        currentlyPlayingTrack = track?.title ?? 'Unknown Track';
      });
      if (previousTrack != null &&
          currentlyPlayingTrack != null &&
          previousTrack != currentlyPlayingTrack) {
        _advanceRoomVisual();
      }
      print('[MUSIC] Now playing: $currentlyPlayingTrack');
    } catch (e) {
      print('[MUSIC] Failed to play lofi music: $e');
      logStateMessage = 'Music: Failed to load';
      setState(() {
        currentlyPlayingTrack = 'Error loading music';
      });
    }
  }

  Future<void> _pauseLofi() async {
    print('[MUSIC] Pausing music...');
    print(
      '[MUSIC] Current track: ${_backgroundMusicService.currentTrack?.title}',
    );
    print('[MUSIC] Is playing: ${_backgroundMusicService.isPlaying}');
    await _backgroundMusicService.pause();
    print('[MUSIC] Pause complete');
  }

  Future<void> _resumeLofi() async {
    if (!_timerController.allowMusic) {
      print('[MUSIC] Resume skipped - music muted');
      return;
    }
    print('[MUSIC] Resume called...');
    print(
      '[MUSIC] Current track: ${_backgroundMusicService.currentTrack?.title}',
    );
    print('[MUSIC] Is playing: ${_backgroundMusicService.isPlaying}');

    if (_backgroundMusicService.currentTrack != null &&
        !_backgroundMusicService.isPlaying &&
        _isCurrentTrackAllowedForRoom()) {
      print('[MUSIC] Resuming or replaying current track...');
      await _backgroundMusicService.ensurePlaying();
      print('[MUSIC] Resume/replay complete');
    } else {
      print('[MUSIC] No track loaded or already playing, playing new track...');
      // If no track is loaded, play a random one
      await _playLofi();
    }
  }

  Future<void> _openTrackPickerModal() async {
    final allTracks = await LofiService.getAllTracks();
    final allowedForRoom = _allowedRoomTrackFilenames();
    final hasRoomScopedTracks =
        selectedRoom != null && allowedForRoom.isNotEmpty;

    if (!mounted) return;

    final picked = await showModalBottomSheet<LofiTrack>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        bool roomOnly = hasRoomScopedTracks;
        String query = '';

        List<LofiTrack> filteredTracks() {
          final scoped = roomOnly
              ? allTracks
                    .where((track) => allowedForRoom.contains(track.filename))
                    .toList()
              : allTracks;
          if (query.trim().isEmpty) return scoped;
          final q = query.toLowerCase();
          return scoped.where((track) {
            return track.title.toLowerCase().contains(q) ||
                track.author.toLowerCase().contains(q) ||
                track.filename.toLowerCase().contains(q);
          }).toList();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleTracks = filteredTracks();
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select track',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Room'),
                            selected: roomOnly,
                            onSelected: hasRoomScopedTracks
                                ? (_) => setModalState(() => roomOnly = true)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: !roomOnly,
                            onSelected: (_) =>
                                setModalState(() => roomOnly = false),
                          ),
                        ],
                      ),
                      if (!hasRoomScopedTracks) ...[
                        const SizedBox(height: 8),
                        Text(
                          'No room-specific tracks set. Showing all tracks.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search track, author, or filename',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: visibleTracks.isEmpty
                            ? Center(
                                child: Text(
                                  'No tracks found',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleTracks.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final track = visibleTracks[index];
                                  final isCurrent =
                                      track.title == currentlyPlayingTrack;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isCurrent
                                          ? Icons.equalizer_rounded
                                          : Icons.music_note,
                                    ),
                                    title: Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${track.author} • ${track.duration}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(track),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;
    await _backgroundMusicService.playTrackById(picked.id);
    setState(() {
      _timerController.setMusicAllowed(true);
      currentlyPlayingTrack = picked.title;
    });
  }

  Set<String> _allowedRoomTrackFilenames() {
    final result = <String>{};
    for (final raw in _roomSelectedTracks) {
      String path = raw.trim();
      if (path.isEmpty) continue;
      if (_isAssetReference(path)) {
        path = path.substring('asset:'.length);
      }
      final normalized = path.replaceAll('\\', '/');
      if (!normalized.contains('/lofi/')) continue;
      final filename = normalized.split('/').last.trim();
      if (filename.isNotEmpty) {
        result.add(filename);
      }
    }
    return result;
  }

  bool _isCurrentTrackAllowedForRoom() {
    if (selectedRoom == null) return true;
    final allowed = _allowedRoomTrackFilenames();
    if (allowed.isEmpty) return true;
    return _backgroundMusicService.isCurrentTrackAllowed(allowed);
  }

  Future<void> _enforceRoomTrackRestriction() async {
    // Changing rooms while timer is idle should not start or change playback.
    if (!_timerController.isRunning) return;
    if (selectedRoom == null) return;
    final allowed = _allowedRoomTrackFilenames();
    if (allowed.isEmpty) return;
    if (_backgroundMusicService.currentTrack == null) return;
    if (_backgroundMusicService.isCurrentTrackAllowed(allowed)) return;
    await _backgroundMusicService.playRandomTrackFromFilenames(allowed);
    if (!mounted) return;
    final previousTrack = currentlyPlayingTrack;
    setState(() {
      currentlyPlayingTrack = _backgroundMusicService.currentTrack?.title;
    });
    if (previousTrack != null &&
        currentlyPlayingTrack != null &&
        previousTrack != currentlyPlayingTrack) {
      _advanceRoomVisual();
    }
  }

  void startTimer() {
    final startingFreshWork =
        !_timerController.onBreak &&
        (sessionStartTime == null ||
            _timerController.remainingSeconds >= workMinutes * 60);
    if (startingFreshWork) {
      unawaited(_flushSessionSquaresIfNewDay());
    }
    setState(() {
      if (!_timerController.onBreak) {
        // New work block after break (or first start), not a mid-session resume.
        if (sessionStartTime == null ||
            _timerController.remainingSeconds >= workMinutes * 60) {
          sessionStartTime = DateTime.now();
        }
      }
    });
    unawaited(_startTimerWithMusic());
    if (startingFreshWork) {
      _showSessionPhaseSnack(_workPhaseMessages);
    }
  }

  Future<void> _startTimerWithMusic() async {
    if (!_timerController.allowMusic) {
      _timerController.startTimer(manageMusic: false);
      return;
    }

    await _soundEffectsService.waitUntilIdle();
    if (_backgroundMusicService.currentTrack != null &&
        !_backgroundMusicService.isPlaying &&
        _isCurrentTrackAllowedForRoom()) {
      await _backgroundMusicService.ensurePlaying();
    } else if (!_backgroundMusicService.isPlaying) {
      await _playLofi();
    }
    _timerController.startTimer(manageMusic: false);
  }

  void _toggleMusicPlayback() {
    setState(() {
      if (_timerController.allowMusic) {
        _pauseLofi();
        _timerController.setMusicAllowed(false);
      } else {
        _timerController.setMusicAllowed(true);
        if (_timerController.isRunning) {
          _resumeLofi();
        }
      }
    });
  }

  void submitLog() {
    saveSession();
    setState(() {
      audioPath = null;
      recordedAudio = null;
      showPlayer = false;
      canSubmitLog = false;
      logStateMessage = "State: Break";
    });

    _timerController.startBreak();
    _showSessionPhaseSnack(_breakPhaseMessages);
  }

  void saveSession({cleanVariables = true}) async {
    countCompletedToday++;

    // Calculate actual minutes spent
    int minutesSpent = workMinutes; // Default to planned minutes
    if (sessionStartTime != null) {
      final actualDuration = DateTime.now().difference(sessionStartTime!);
      minutesSpent = actualDuration.inMinutes;
      // Ensure minimum of 1 minute and maximum of planned minutes + 5 (for flexibility)
      minutesSpent = minutesSpent.clamp(1, workMinutes + 5);
    }

    final session = PomodoroModel(
      startTime: sessionStartTime ?? DateTime.now(),
      audioPath: audioPath,
      imagePath: imagePath,
      dayPomodoroNumber: countCompletedToday + 1,
      duration: minutesSpent.toString(),
      durationMinutes: minutesSpent,
      project_id: selectedProject?.id,
      project_name: selectedProject?.name,
    );
    final box = Hive.box<PomodoroModel>('pomodoros');
    await box.add(session);

    // Update project statistics if a project is selected
    if (selectedProject != null) {
      selectedProject!.addPomodoroSession();
    }

    // Record session stats + grant points and card loot (points + cards only).
    if (userProgress != null) {
      userProgress!.recordSession(sessionDate: session.startTime);
      final loot = SessionRewardService.grant(
        minutes: minutesSpent,
        kind: SessionKind.focus,
        progress: userProgress,
      );
      if (mounted) {
        await showSessionLootDialog(context, loot);
      }
    }

    print(
      "Saved session at ${session.startTime} - Duration: $minutesSpent minutes",
    );
    if (cleanVariables) {
      audioPath = null;
      recordedAudio = null;
      imagePath = null;
      showPlayer = false;
      sessionStartTime = null;
    }
  }

  Future<void> _persistSessionRecording(EnhancedAudioModel audioModel) async {
    try {
      if (!Hive.isBoxOpen('audioFiles')) {
        await Hive.openBox<EnhancedAudioModel>('audioFiles');
      }
      final box = Hive.box<EnhancedAudioModel>('audioFiles');
      await box.add(audioModel);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, text: 'Could not save recording to library: $e');
    }
  }

  void takePhoto() async {
    String? path = await capturePhoto(context);

    if (path != null) {
      setState(() {
        imagePath = path;
      });
    }
  }

  void stopTimer() {
    _timerController.pauseTimer();
    if (audioPath != null) {
      final file = File(audioPath!);
      if (file.existsSync()) file.deleteSync();
      audioPath = null;
    }
    setState(() {
      recordedAudio = null;
      showPlayer = false;
      sessionStartTime = null;
    });
  }

  void resetTimer() {
    _timerController.resetTimer();
    setState(() {
      sessionStartTime = null;
    });
  }

  void toggleMute() {
    setState(() {
      _timerController.toggleMute();
    });
  }

  void instantFinish() {
    // Set timer to 1 second to let it complete naturally
    _timerController.setRemainingSeconds(1);
  }

  Future<void> _openRoomManagement() async {
    setState(() {
      _isRoomQuickPickerOpen = false;
    });
    final result = await Navigator.of(context).push<RoomManagementResult>(
      MaterialPageRoute(
        builder: (_) =>
            RoomManagementScreen(rooms: rooms, selectedRoom: selectedRoom),
      ),
    );

    if (!mounted || result == null) return;

    // Refresh rooms first so we can resolve the returned selection against
    // the latest room list from storage.
    await _loadRooms();
    await _loadRoomQuickPickerVisuals();
    if (!mounted) return;

    final latestRooms = List<RoomModel>.from(rooms);
    RoomModel? selected = selectedRoom;
    if (result.selectedRoomId == null) {
      selected = null;
    } else {
      for (final room in latestRooms) {
        if (room.id == result.selectedRoomId) {
          selected = room;
          break;
        }
      }
    }

    setState(() {
      selectedRoom = selected;
    });
    await _loadSelectedRoomPhrases();
  }

  Future<void> _openProjectManagement() async {
    final selectedProjectId = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => ProjectsManagementScreen(
          initialSelectedProjectId: selectedProject?.id,
        ),
      ),
    );
    if (!mounted) return;
    await _loadProjects();
    if (!mounted) return;
    setState(() {
      if (selectedProjectId == null) {
        selectedProject = null;
      } else {
        ProjectModel? nextSelected;
        for (final project in projects) {
          if (project.id == selectedProjectId) {
            nextSelected = project;
            break;
          }
        }
        selectedProject = nextSelected;
      }
      if (selectedProject != null) {
        workMinutes = selectedProject!.workDurationMinutes;
        breakMinutes = selectedProject!.breakDurationMinutes;
      } else {
        workMinutes = userSettings?.defaultWorkMinutes ?? 25;
        breakMinutes = userSettings?.defaultBreakMinutes ?? 5;
      }
      _timerController.updateDurations(workMinutes, breakMinutes);
      if (!_timerController.isRunning && !_timerController.onBreak) {
        remainingSeconds = workMinutes * 60;
      }
    });
    await _loadSelectedRoomPhrases();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerController.addListener(_onTimerStateChanged);
    // Simplified initialization to prevent hanging
    _safeInitialize();
  }

  void _safeInitialize() async {
    try {
      await _loadConfig();
      await _loadUserSettings();
      await RoomManagementSeedService.ensureSampleRooms();
      await ProjectSeedService.ensureSampleProjects();
      await RewardSeedService.ensureDefaultBoardgameRewards();
      await MotivationSeedService.ensureSeeded();
      await _loadRooms();
      await _loadProjects();
      await _loadSelectedRoomPhrases();
      await _loadUserProgress();
      await _backgroundMusicService.initialize();
      await _timerController.initialize();
      final count = await getTodayCompletedSessions();
      if (mounted) {
        setState(() => countCompletedToday = count);
      }
    } catch (e) {
      print('Initialization error: $e');
      // Continue with defaults even if initialization fails
      if (mounted) {
        setState(() {
          countCompletedToday = 0;
        });
      }
    }
  }

  Future<void> _loadUserProgress() async {
    try {
      if (!Hive.isBoxOpen('userProgress')) {
        await Hive.openBox<UserProgressModel>('userProgress');
      }
      final box = Hive.box<UserProgressModel>('userProgress');

      userProgress = box.get('progress');
      if (userProgress == null) {
        // Create new progress tracking with a small starting balance
        // (for testing; adjust startingPoints as needed).
        userProgress = UserProgressModel(availablePoints: 100);
        await box.put('progress', userProgress!);

        // Initialize empty rewards box if it doesn't exist
        await _initializeRewardsBox();
      }

      setState(() {});
    } catch (e) {
      print('Error loading user progress: $e');
      userProgress = UserProgressModel();
      setState(() {});
    }
  }

  Future<void> _initializeRewardsBox() async {
    try {
      if (!Hive.isBoxOpen('rewards')) {
        await Hive.openBox<RewardModel>('rewards');
      }
      print('✓ Rewards box initialized (user-created rewards only)');
    } catch (e) {
      print('Error initializing rewards box: $e');
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final box = Hive.box<UserSettingsModel>('userSettings');
      userSettings = box.get('settings') ?? UserSettingsModel();
      setState(() {
        workMinutes = userSettings!.defaultWorkMinutes;
        breakMinutes = userSettings!.defaultBreakMinutes;
        if (!isRunning && !onBreak) {
          remainingSeconds = workMinutes * 60;
        }
      });
    } catch (e) {
      print('Error loading user settings: $e');
      setState(() {
        workMinutes = 25;
        breakMinutes = 5;
        remainingSeconds = workMinutes * 60;
      });
    }
  }

  Future<void> _loadProjects() async {
    try {
      if (!Hive.isBoxOpen('projects')) {
        await Hive.openBox<ProjectModel>('projects');
      }
      final box = Hive.box<ProjectModel>('projects');

      // Load only active projects (user-created projects)
      final allProjects = box.values.toList();
      final activeProjects = allProjects.where((p) => p.isActive).toList();

      setState(() {
        projects = activeProjects;
      });

      print('Loaded ${activeProjects.length} active projects');
    } catch (e) {
      print('Error loading projects: $e');
      setState(() {
        projects = [];
      });
    }
  }

  Future<void> _loadRooms() async {
    try {
      if (!Hive.isBoxOpen('rooms')) {
        await Hive.openBox('rooms');
      }
      final box = Hive.box('rooms');
      final loadedRooms = box.values
          .whereType<Map>()
          .map(RoomModel.fromMap)
          .where((room) => room.isActive)
          // Only rooms unlocked through the cards system appear in the pomodoro.
          .where((room) => UnlockService.isUnlocked('room:${room.id}'))
          .toList();

      setState(() {
        rooms = loadedRooms;
        if (selectedRoom != null &&
            !loadedRooms.any((room) => room.id == selectedRoom!.id)) {
          selectedRoom = null;
          _isRoomQuickPickerOpen = false;
        }
      });
      await _loadRoomQuickPickerVisuals();
    } catch (e) {
      print('Error loading rooms: $e');
      setState(() {
        rooms = [];
      });
    }
  }

  Future<void> _loadConfig() async {
    try {
      final box = Hive.box<ConfigModel>('config');
      config = box.get('settings') ?? ConfigModel.getDefault();
      setState(() {});
    } catch (e) {
      print('Error loading config: $e');
      config = ConfigModel.getDefault();
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh projects when app is resumed
      _loadRooms();
      _loadProjects();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Show notification when app goes to background
      if (_timerController.isRunning) {
        _notificationService.showTimerNotification(
          remainingSeconds: _timerController.remainingSeconds,
          isRunning: _timerController.isRunning,
          isBreak: _timerController.onBreak,
          onPlay: startTimer,
          onPause: stopTimer,
          onReset: resetTimer,
          onMute: toggleMute,
        );
      }
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh projects when returning to home screen
    _loadRooms();
    _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _buildSideActionFabs(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_isRoomQuickPickerOpen) {
              setState(() {
                _isRoomQuickPickerOpen = false;
              });
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Main Timer Display
                _buildTimerSection(),

                // Recording and Photo Section (conditional)
                // _buildConditionalRecordingSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSection() {
    // Same horizontal inset as the album block in `_buildGestureTimer`.
    const albumHorizontalInset = 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timer with recording buttons when session complete
        if (projects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: albumHorizontalInset),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProjectSelectorWidget(
                projects: projects,
                selectedProject: selectedProject,
                isRunning: _timerController.isRunning,
                canSubmitLog: canSubmitLog,
                selectedExpandedWidth: PomodoroSizing.getAlbumContainerSize(
                  context,
                ),
                onProjectSelected: (project) {
                  setState(() {
                    selectedProject = project;
                    // Update timer durations based on selected project
                    if (project != null) {
                      workMinutes = project.workDurationMinutes;
                      breakMinutes = project.breakDurationMinutes;
                      _timerController.updateDurations(workMinutes, breakMinutes);
                    } else {
                      // No project selected, use user default settings
                      workMinutes = userSettings?.defaultWorkMinutes ?? 25;
                      breakMinutes = userSettings?.defaultBreakMinutes ?? 5;
                      _timerController.updateDurations(workMinutes, breakMinutes);
                    }
                  });
                  _loadSelectedRoomPhrases();
                },
                isCollapsed: false, // Always show full project info when visible
              ),
            ),
          ),
        canSubmitLog ? _buildTimerWithRecordingButtons() : _buildGestureTimer(),
      ],
    );
  }

  /// Long-break queue (videos / playlists) while timer is paused mid work or break.
  bool get _showLongBreakDuringPause =>
      !canSubmitLog && _timerController.isMidSessionPaused;

  void _openLongBreakSheet() => showLongBreakModal(context);

  Widget _buildGestureTimer() {
    final mediaWidget = _currentPomodoroMediaWidget(playing: isRunning);
    return GestureDetector(
      onTap: () {
        print('[HOME] Timer tapped!');
        print(
          '[HOME] isRunning: ${_timerController.isRunning}, canSubmitLog: $canSubmitLog',
        );
        // Click timer to start/stop/submit log
        if (_timerController.isRunning) {
          print('[HOME] Calling pauseTimer()');
          _timerController.pauseTimer();
        } else if (canSubmitLog) {
          print('[HOME] Calling submitLog()');
          submitLog();
        } else {
          print('[HOME] Calling startTimer()');
          startTimer();
        }
      },
      onVerticalDragEnd: (details) {
        // Swipe up for instant finish, swipe down for reset
        if (details.velocity.pixelsPerSecond.dy < -300) {
          // Swipe up - instant finish current session (work or break)
          if (_timerController.isRunning) {
            instantFinish();
          }
        } else if (details.velocity.pixelsPerSecond.dy > 300) {
          // Swipe down - reset timer
          if (!_timerController.isRunning) {
            _timerController.resetTimer();
          }
        }
      },
      child: Container(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MediaQuery.of(context).size.width > 600
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Album image with timer overlay
                      SizedBox(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        child: Stack(
                          children: [
                            // Album background image
                            Container(
                              width: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              height: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColorPalette.success,
                                  width: 2,
                                ),
                                color: mediaWidget == null
                                    ? AppColorPalette.success.withValues(
                                        alpha: 0.1,
                                      )
                                    : null,
                              ),
                              child: mediaWidget == null
                                  ? null
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: mediaWidget,
                                    ),
                            ),
                            // Timer overlay with semi-transparent background
                            Container(
                              width: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              height: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(
                                  context,
                                ).colorScheme.shadow.withValues(alpha: 0.3),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAnimatedTimerText(),
                                  const SizedBox(height: AppUiSizes.sm),
                                  _buildTimerOverlayText(),
                                  const SizedBox(height: AppUiSizes.sm),
                                  SessionSquaresWidget(
                                    completedSessions: countCompletedToday,
                                  ),
                                ],
                              ),
                            ),
                            if (selectedProject != null)
                              Positioned(
                                top: 8,
                                right: 10,
                                child: _buildSelectedProjectOverlayText(),
                              ),
                            if (selectedRoom != null)
                              Positioned(
                                top: 8,
                                left: 10,
                                child: _buildSelectedRoomOverlayText(),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(width: 20),

                      // Music widget next to album (hidden when paused)
                      if (isRunning || canSubmitLog)
                        SizedBox(
                          width: PomodoroSizing.getMusicWidgetWidth(context),
                          child: CompactMusicWidget(
                            allowMusic: _timerController.allowMusic,
                            currentlyPlayingTrack: currentlyPlayingTrack,
                            onToggleMusic: _toggleMusicPlayback,
                            onChangeTrack: () {
                              if (_timerController.allowMusic) {
                                _playLofi();
                              }
                            },
                            onLongPressTrackPicker: _openTrackPickerModal,
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top padding to match bottom spacing
                      SizedBox(height: 20),
                      // Album image with timer overlay
                      SizedBox(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        child: Stack(
                          children: [
                            // Album background image
                            Container(
                              width: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              height: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColorPalette.success,
                                  width: 2,
                                ),
                                color: mediaWidget == null
                                    ? AppColorPalette.success.withValues(
                                        alpha: 0.1,
                                      )
                                    : null,
                              ),
                              child: mediaWidget == null
                                  ? null
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: mediaWidget,
                                    ),
                            ),
                            // Timer overlay with semi-transparent background
                            Container(
                              width: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              height: PomodoroSizing.getAlbumContainerSize(
                                context,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(
                                  context,
                                ).colorScheme.shadow.withValues(alpha: 0.3),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAnimatedTimerText(),
                                  const SizedBox(height: AppUiSizes.sm),
                                  _buildTimerOverlayText(),
                                  const SizedBox(height: AppUiSizes.sm),
                                  SessionSquaresWidget(
                                    completedSessions: countCompletedToday,
                                  ),
                                ],
                              ),
                            ),
                            if (selectedProject != null)
                              Positioned(
                                top: 8,
                                right: 10,
                                child: _buildSelectedProjectOverlayText(),
                              ),
                            if (selectedRoom != null)
                              Positioned(
                                top: 8,
                                left: 10,
                                child: _buildSelectedRoomOverlayText(),
                              ),
                          ],
                        ),
                      ),

                      // Music widget below album for small screens (hidden when paused)
                      if (isRunning || canSubmitLog) ...[
                        SizedBox(height: 20),
                        SizedBox(
                          width: PomodoroSizing.getAlbumContainerSize(
                            context,
                          ).clamp(150.0, 400.0),
                          child: CompactMusicWidget(
                            allowMusic: _timerController.allowMusic,
                            currentlyPlayingTrack: currentlyPlayingTrack,
                            onToggleMusic: _toggleMusicPlayback,
                            onChangeTrack: () {
                              if (_timerController.allowMusic) {
                                _playLofi();
                              }
                            },
                            onLongPressTrackPicker: _openTrackPickerModal,
                          ),
                        ),
                      ],
                    ],
                  ),
            if (_showLongBreakDuringPause) ...[
              const SizedBox(height: AppUiSizes.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openLongBreakSheet,
                  icon: const Icon(Icons.video_library_outlined, size: 20),
                  label: const Text('Long break'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerWithRecordingButtons() {
    return MediaQuery.of(context).size.width > 600
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Album image with timer overlay (center)
              SizedBox(
                width: PomodoroSizing.getAlbumContainerSize(context),
                height: PomodoroSizing.getAlbumContainerSize(context),
                child: GestureDetector(
                  onTap: () {
                    if (canSubmitLog) {
                      submitLog();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    // Swipe up for instant finish, swipe down for reset
                    if (details.velocity.pixelsPerSecond.dy < -300) {
                      // Swipe up - instant finish current session (work or break)
                      if (isRunning) {
                        instantFinish();
                      }
                    } else if (details.velocity.pixelsPerSecond.dy > 300) {
                      // Swipe down - reset timer
                      if (!isRunning) {
                        resetTimer();
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      // Timer overlay with semi-transparent background
                      Container(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAnimatedTimerText(),
                            SizedBox(height: 8),
                            _buildTimerOverlayText(),
                            SizedBox(height: 8),
                            SessionSquaresWidget(
                              completedSessions: countCompletedToday,
                            ),
                          ],
                        ),
                      ),
                      if (selectedProject != null)
                        Positioned(
                          top: 8,
                          right: 10,
                          child: _buildSelectedProjectOverlayText(),
                        ),
                      if (selectedRoom != null)
                        Positioned(
                          top: 8,
                          left: 10,
                          child: _buildSelectedRoomOverlayText(),
                        ),
                    ],
                  ),
                ),
              ),
              // vertical stack for horizontal layout
              Column(
                children: [
                  // Recording button (right side)
                  if (config?.showAudioRecordButton == true)
                    Container(
                      margin: EdgeInsets.only(left: 20, top: 10, bottom: 10),
                      child: _buildSimplifiedRecordingButton(),
                    ),

                  if (config?.showPhotoButton == true)
                    Container(
                      margin: EdgeInsets.only(left: 20, bottom: 10),
                      child: _buildSquareEvidenceButton(),
                    ),
                  if (recordedAudio != null)
                    Container(
                      margin: const EdgeInsets.only(
                        left: 20,
                        top: 4,
                        bottom: 8,
                      ),
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: SessionRecordingPreview(audio: recordedAudio!),
                    ),
                  if (isRunning || canSubmitLog)
                    Container(
                      width: PomodoroSizing.getMusicWidgetWidth(context),
                      margin: EdgeInsets.only(left: 20, top: 10),
                      child: CompactMusicWidget(
                        allowMusic: _timerController.allowMusic,
                        currentlyPlayingTrack: currentlyPlayingTrack,
                        onToggleMusic: _toggleMusicPlayback,
                        onChangeTrack: () {
                          if (_timerController.allowMusic) {
                            _playLofi();
                          }
                        },
                        onLongPressTrackPicker: _openTrackPickerModal,
                      ),
                    ),
                ],
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding to match bottom spacing
              SizedBox(height: 20),
              // Album image with timer overlay for vertical layout
              SizedBox(
                width: PomodoroSizing.getAlbumContainerSize(context),
                height: PomodoroSizing.getAlbumContainerSize(context),
                child: GestureDetector(
                  onTap: () {
                    if (canSubmitLog) {
                      submitLog();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    // Swipe up for instant finish, swipe down for reset
                    if (details.velocity.pixelsPerSecond.dy < -300) {
                      // Swipe up - instant finish current session (work or break)
                      if (isRunning) {
                        instantFinish();
                      }
                    } else if (details.velocity.pixelsPerSecond.dy > 300) {
                      // Swipe down - reset timer
                      if (!isRunning) {
                        resetTimer();
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      // Timer overlay with semi-transparent background
                      Container(
                        width: PomodoroSizing.getAlbumContainerSize(context),
                        height: PomodoroSizing.getAlbumContainerSize(context),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAnimatedTimerText(),
                            SizedBox(height: 8),
                            _buildTimerOverlayText(),
                            SizedBox(height: 8),
                            SessionSquaresWidget(
                              completedSessions: countCompletedToday,
                            ),
                          ],
                        ),
                      ),
                      if (selectedProject != null)
                        Positioned(
                          top: 8,
                          right: 10,
                          child: _buildSelectedProjectOverlayText(),
                        ),
                      if (selectedRoom != null)
                        Positioned(
                          top: 8,
                          left: 10,
                          child: _buildSelectedRoomOverlayText(),
                        ),
                    ],
                  ),
                ),
              ),

              // Recording and camera buttons below timer for vertical layout
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Recording button
                  if (config?.showAudioRecordButton == true) ...[
                    _buildSimplifiedRecordingButton(),
                    if (config?.showPhotoButton == true) SizedBox(width: 20),
                  ],

                  // Camera button
                  if (config?.showPhotoButton == true)
                    _buildSquareEvidenceButton(),
                ],
              ),

              if (recordedAudio != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SessionRecordingPreview(audio: recordedAudio!),
                    ),
                  ),
                ),
              ],

              // Music widget below recording buttons for vertical layout
              if (isRunning || canSubmitLog) ...[
                SizedBox(height: 20),
                SizedBox(
                  width: PomodoroSizing.getAlbumContainerSize(
                    context,
                  ).clamp(150.0, 400.0),
                  child: CompactMusicWidget(
                    allowMusic: _timerController.allowMusic,
                    currentlyPlayingTrack: currentlyPlayingTrack,
                    onToggleMusic: _toggleMusicPlayback,
                    onChangeTrack: () {
                      if (_timerController.allowMusic) {
                        _playLofi();
                      }
                    },
                    onLongPressTrackPicker: _openTrackPickerModal,
                  ),
                ),
              ],
            ],
          );
  }

  Widget _buildSquareEvidenceButton() {
    final warningColor = AppColorPalette.warning;
    final successColor = AppColorPalette.success;
    return GestureDetector(
      onTap: takePhoto,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: (imagePath != null)
              ? successColor.withValues(alpha: 0.1)
              : warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (imagePath != null) ? successColor : warningColor,
            width: 2,
          ),
        ),
        child: Icon(
          (imagePath != null) ? Icons.camera_alt : Icons.camera_alt_outlined,
          size: 24,
          color: (imagePath != null) ? successColor : warningColor,
        ),
      ),
    );
  }

  Widget _buildSimplifiedRecordingButton() {
    return _SimplifiedRecordingWidget(
      onRecordingComplete: (audioModel) {
        _soundEffectsService.playAudioRecordSubmitted();
        _persistSessionRecording(audioModel);
        setState(() {
          audioPath = audioModel.filePath;
          recordedAudio = audioModel;
          showPlayer = true;
          canSubmitLog = true;
        });
        showAppSnack(context, text: 'Recording completed successfully!');
      },
      onReset: () {
        setState(() {
          audioPath = null;
          recordedAudio = null;
          showPlayer = false;
        });
      },
      hasRecording: audioPath != null,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerController.removeListener(_onTimerStateChanged);
    _bgPlayer.dispose();
    _backgroundMusicService.dispose();
    _soundEffectsService.dispose();
    _notificationService.dispose();
    _stopRoomPhraseRotation(clearCurrent: false);
    super.dispose();
  }
}

class _HomeSpeedControlledGif extends StatefulWidget {
  final String sourcePath;
  final bool isAssetReference;
  final double speed;

  /// When false, animation stops (timer paused — work or break).
  final bool playing;
  final BoxFit fit;
  final Widget? errorChild;

  const _HomeSpeedControlledGif({
    required this.sourcePath,
    required this.isAssetReference,
    required this.speed,
    this.playing = true,
    this.fit = BoxFit.contain,
    this.errorChild,
  });

  @override
  State<_HomeSpeedControlledGif> createState() =>
      _HomeSpeedControlledGifState();
}

class _HomeSpeedControlledGifState extends State<_HomeSpeedControlledGif> {
  List<ui.FrameInfo> _frames = const [];
  int _frameIndex = 0;
  Timer? _frameTimer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  @override
  void didUpdateWidget(covariant _HomeSpeedControlledGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        widget.sourcePath != oldWidget.sourcePath ||
        widget.isAssetReference != oldWidget.isAssetReference;
    if (sourceChanged) {
      _frameTimer?.cancel();
      _frames = const [];
      _frameIndex = 0;
      _failed = false;
      _loadFrames();
      return;
    }
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        if (_frames.isNotEmpty) _scheduleNextFrame();
      } else {
        _frameTimer?.cancel();
      }
    } else if (widget.speed != oldWidget.speed && _frames.isNotEmpty) {
      _frameTimer?.cancel();
      _scheduleNextFrame();
    }
  }

  Future<void> _loadFrames() async {
    try {
      final bytes = await _loadBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frames = <ui.FrameInfo>[];
      for (var i = 0; i < codec.frameCount; i++) {
        frames.add(await codec.getNextFrame());
      }
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _frameIndex = 0;
        _failed = false;
      });
      if (widget.playing) _scheduleNextFrame();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
    }
  }

  Future<Uint8List> _loadBytes() async {
    if (widget.isAssetReference) {
      final path = widget.sourcePath.startsWith('asset:')
          ? widget.sourcePath.substring('asset:'.length)
          : widget.sourcePath;
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    }
    if (widget.sourcePath.startsWith('data:')) {
      final comma = widget.sourcePath.indexOf(',');
      if (comma < 0 || comma >= widget.sourcePath.length - 1) {
        return Uint8List(0);
      }
      return base64Decode(widget.sourcePath.substring(comma + 1));
    }
    final file = File(widget.sourcePath);
    return file.readAsBytes();
  }

  void _scheduleNextFrame() {
    if (!mounted || _frames.isEmpty || !widget.playing) return;
    final current = _frames[_frameIndex];
    final baseMs = current.duration.inMilliseconds <= 0
        ? 100
        : current.duration.inMilliseconds;
    final speed = widget.speed <= 0 ? 1.0 : widget.speed;
    final nextMs = (baseMs / speed).clamp(16, 1000).toInt();
    _frameTimer = Timer(Duration(milliseconds: nextMs), () {
      if (!mounted || _frames.isEmpty || !widget.playing) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });
      _scheduleNextFrame();
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorChild ??
          Container(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
    }
    if (_frames.isEmpty) {
      return const SizedBox.shrink();
    }
    return RawImage(
      image: _frames[_frameIndex].image,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _SimplifiedRecordingWidget extends StatefulWidget {
  final Function(EnhancedAudioModel) onRecordingComplete;
  final VoidCallback onReset;
  final bool hasRecording;

  const _SimplifiedRecordingWidget({
    required this.onRecordingComplete,
    required this.onReset,
    required this.hasRecording,
  });

  @override
  State<_SimplifiedRecordingWidget> createState() =>
      _SimplifiedRecordingWidgetState();
}

class _SimplifiedRecordingWidgetState extends State<_SimplifiedRecordingWidget>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _stopRecordingInProgress = false;
  double _smoothedMicLevel = 0;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  Timer? _levelTimer;

  final List<double> _audioLevels = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _audioLevels.clear();
        _smoothedMicLevel = 0;
      });

      _pulseController.repeat(reverse: true);
      _startTimer();
      _startLevelMonitoring();
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_stopRecordingInProgress || !_isRecording) return;
    _stopRecordingInProgress = true;
    _timer?.cancel();
    _levelTimer?.cancel();
    _pulseController.stop();
    try {
      final path = await _recorder.stop();

      if (path != null) {
        final audioModel = EnhancedAudioModel(
          filePath: path,
          fileName: path.split('/').last,
          createdAt: DateTime.now(),
          durationMs: _recordingDuration.inMilliseconds,
          fileSizeBytes: 0, // Will be calculated later
          format: 'wav',
          bitRate: 128000,
          sampleRate: 44100,
          channels: 1,
          title: 'Session Recording',
          description: 'Pomodoro session recording',
          tags: ['session'],
          category: 'session',
          waveformData: _audioLevels,
        );
        widget.onRecordingComplete(audioModel);
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _smoothedMicLevel = 0;
        });
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _smoothedMicLevel = 0;
        });
      }
    } finally {
      _stopRecordingInProgress = false;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(
          seconds: _recordingDuration.inSeconds + 1,
        );
      });
    });
  }

  void _startLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!_isRecording || !mounted) return;
      try {
        final amplitude = await _recorder.getAmplitude();
        final normalized = normalizeMicDb(amplitude.current);

        if (!mounted || !_isRecording) return;
        setState(() {
          _smoothedMicLevel = _smoothedMicLevel * 0.74 + normalized * 0.26;
          _audioLevels.add(_smoothedMicLevel);
          if (_audioLevels.length > 50) {
            _audioLevels.removeAt(0);
          }
        });
      } catch (e) {
        // Handle amplitude error silently
      }
    });
  }

  Widget _buildAudioLevelsVisualization(Color waveformAccent) {
    if (!_isRecording) return SizedBox.shrink();

    return IgnorePointer(
      child: Positioned.fill(
        child: CustomPaint(
          painter: _AudioLevelsPainter(_audioLevels, waveformAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final errorColor = AppColorPalette.error;
        final successColor = AppColorPalette.success;
        final infoColor = AppColorPalette.info;
        final micHot = AppColorPalette.warning;
        final rawLevel = _smoothedMicLevel.clamp(0.0, 1.0);
        final intensity = pow(rawLevel, 0.34).toDouble().clamp(0.0, 1.0);
        final recordingAccent = _isRecording
            ? Color.lerp(errorColor, micHot, intensity)!
            : errorColor;
        final recordingFill = _isRecording
            ? Color.lerp(
                errorColor.withValues(alpha: 0.03),
                micHot.withValues(alpha: 0.12 + 0.38 * intensity),
                intensity,
              )!
            : errorColor.withValues(alpha: 0.1);
        final recordingBorder = _isRecording ? recordingAccent : errorColor;
        final recordingIconColor = _isRecording
            ? recordingAccent
            : AppColorPalette.error;
        final borderWidth = _isRecording ? 2.0 + 5.5 * intensity : 2.0;

        return Transform.scale(
          scale: _isRecording ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.hasRecording && !_isRecording) {
                widget.onReset();
              } else if (_isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording
                    ? recordingFill
                    : widget.hasRecording
                    ? successColor.withValues(alpha: 0.1)
                    : infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isRecording && intensity > 0.12
                    ? [
                        BoxShadow(
                          color: recordingAccent.withValues(
                            alpha: 0.15 + 0.55 * intensity,
                          ),
                          blurRadius: 4 + 14 * intensity,
                          spreadRadius: -0.5,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: _isRecording
                      ? recordingBorder
                      : widget.hasRecording
                      ? successColor
                      : infoColor,
                  width: borderWidth,
                ),
              ),
              child: Stack(
                children: [
                  _buildAudioLevelsVisualization(recordingAccent),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRecording
                              ? Icons.stop
                              : widget.hasRecording
                              ? Icons.refresh
                              : Icons.mic,
                          size: 24,
                          color: _isRecording
                              ? recordingIconColor
                              : widget.hasRecording
                              ? AppColorPalette.success
                              : AppColorPalette.info,
                        ),
                        if (_isRecording) ...[
                          const SizedBox(height: AppUiSizes.xs),
                          Text(
                            '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: AppColorPalette.fontSizeXSmall,
                              color: recordingAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

class _AudioLevelsPainter extends CustomPainter {
  final List<double> levels;
  final Color accent;

  _AudioLevelsPainter(this.levels, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final paint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    final barWidth = size.width / levels.length;

    for (int i = 0; i < levels.length; i++) {
      final barHeight = levels[i] * (size.height * 0.6);
      final x = i * barWidth + barWidth / 2;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

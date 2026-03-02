import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/lofi_track.dart';
import 'package:solo_level_system/models/room_model.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

class RoomManagementResult {
  final String? selectedRoomId;

  const RoomManagementResult({required this.selectedRoomId});
}

class RoomManagementScreen extends StatefulWidget {
  final List<RoomModel> rooms;
  final RoomModel? selectedRoom;

  const RoomManagementScreen({
    super.key,
    required this.rooms,
    required this.selectedRoom,
  });

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  static const String _roomsBoxName = 'rooms';
  static const String _boxName = 'roomManagement';
  static const String _randomRoomKey = '__random__';
  static const String _spaceRoomId = 'sample-room-space-station-study';
  static const String _mansionRoomId = 'sample-room-abandoned-mansion-study';
  static const String _spaceIconAsset = 'assets/album/al16-spaceship.png';
  static const String _mansionIconAsset =
      'assets/album/an02_model1_working_2.gif';
  static const double _basePreviewVolume = 0.25;
  static const List<String> _supportedAudioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'flac',
  ];
  static const List<String> _supportedVisualExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];

  final AudioPlayer _previewPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  late final PageController _roomPageController;
  late final List<RoomModel> _rooms;

  RoomModel? _selectedRoom;
  double _volume = 0.7;
  int _volumeLevel = 3;
  List<String> _roomPhrases = [];
  final Map<String, List<String>> _roomPhrasesByKey = {};
  List<String> _selectedTracks = [];
  List<RoomVisualConfig> _selectedVisuals = [];
  List<LofiTrack> _builtinTracks = [];
  List<EnhancedAudioModel> _libraryTracks = [];
  bool _isLoading = true;
  bool _isTracksExpanded = true;
  bool _isVisualsExpanded = true;
  String? _currentlyPreviewingPath;
  Timer? _previewAutoStopTimer;
  final Random _randomizer = Random();

  @override
  void initState() {
    super.initState();
    _rooms = List<RoomModel>.from(widget.rooms);
    _selectedRoom = widget.selectedRoom;
    _roomPageController = PageController(
      viewportFraction: 0.78,
      initialPage: _currentPageForSelectedRoom(),
    );
    _loadRoomContext();
  }

  @override
  void dispose() {
    _previewAutoStopTimer?.cancel();
    _roomPageController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  String get _roomStorageKey => _selectedRoom?.id ?? _randomRoomKey;

  Future<Box<dynamic>> _openRoomBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  Future<Box<dynamic>> _openRoomsBox() async {
    if (Hive.isBoxOpen(_roomsBoxName)) {
      return Hive.box(_roomsBoxName);
    }
    return Hive.openBox(_roomsBoxName);
  }

  Future<void> _upsertRoom(RoomModel room) async {
    final box = await _openRoomsBox();
    await box.put(room.id, room.toMap());
  }

  Future<void> _loadRoomContext() async {
    setState(() => _isLoading = true);
    try {
      _builtinTracks = await LofiService.getAllTracks();
      final audioBox = Hive.box<EnhancedAudioModel>('audioFiles');
      _libraryTracks = audioBox.values.toList();

      final roomBox = await _openRoomBox();
      final nextPhrasesByKey = <String, List<String>>{};
      final roomConfigs = roomBox.toMap();
      for (final entry in roomConfigs.entries) {
        final value = entry.value;
        if (value is Map) {
          final model = RoomManagementModel.fromMap(value);
          nextPhrasesByKey[entry.key.toString()] = model.phrases;
        }
      }
      _roomPhrasesByKey
        ..clear()
        ..addAll(nextPhrasesByKey);

      await _loadRoomConfiguration();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load room management data: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRoomConfiguration() async {
    final box = await _openRoomBox();
    final raw = box.get(_roomStorageKey);
    if (raw is Map) {
      final model = RoomManagementModel.fromMap(raw);
      if (!mounted) return;
      setState(() {
        _selectedTracks = model.selectedTracks;
        _selectedVisuals = model.selectedVisuals;
        _roomPhrases = model.phrases;
        _roomPhrasesByKey[_roomStorageKey] = model.phrases;
        _volume = model.volume.clamp(0.0, 1.0);
        _volumeLevel = _volumeToLevel(_volume);
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedTracks = [];
      _selectedVisuals = [];
      _roomPhrases = [];
      _roomPhrasesByKey[_roomStorageKey] = const [];
      _volumeLevel = 1;
      _volume = _levelToVolume(_volumeLevel);
    });
  }

  Future<void> _persistRoomConfiguration() async {
    final box = await _openRoomBox();
    final model = RoomManagementModel(
      selectedTracks: _selectedTracks,
      selectedVisuals: _selectedVisuals,
      volume: _volume,
      phrases: _roomPhrases,
    );
    await box.put(_roomStorageKey, model.toMap());
    _roomPhrasesByKey[_roomStorageKey] = List<String>.from(_roomPhrases);
  }

  Future<void> _selectRoom(RoomModel? room, {bool centerCard = true}) async {
    setState(() {
      _selectedRoom = room;
    });
    if (centerCard) {
      await _centerSelectedRoomCard(room);
    }
    await _loadRoomConfiguration();
  }

  Future<void> _centerSelectedRoomCard(RoomModel? room) async {
    final targetPage = room == null
        ? 0
        : (_rooms.indexWhere((item) => item.id == room.id) + 1);
    if (!_roomPageController.hasClients || targetPage < 0) return;
    await _roomPageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _selectRandomSpecificRoom() async {
    if (_rooms.isEmpty) return;
    final randomRoom = _rooms[_randomizer.nextInt(_rooms.length)];
    await _selectRoom(randomRoom);
  }

  Widget _buildRoomDialogContent(BuildContext dialogContext, Widget child) {
    final size = MediaQuery.of(dialogContext).size;
    final dialogWidth = size.width * 0.9;
    final dialogMaxHeight = size.height * 0.78;

    return SizedBox(
      width: dialogWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        child: SingleChildScrollView(child: child),
      ),
    );
  }

  Future<void> _showCreateRoomDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final phrasesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Room'),
          content: _buildRoomDialogContent(
            dialogContext,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phrasesController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Phrases (one per line)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title cannot be empty')),
                  );
                  return;
                }

                final description = descriptionController.text.trim();
                final phrases = phrasesController.text
                    .split('\n')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();

                final room = RoomModel(
                  id: 'room_${DateTime.now().millisecondsSinceEpoch}',
                  name: title,
                  description: description.isEmpty ? null : description,
                );
                await _upsertRoom(room);

                if (!mounted) return;
                setState(() {
                  _rooms.add(room);
                });
                await _selectRoom(room);

                if (phrases.isNotEmpty) {
                  setState(() {
                    _roomPhrases = phrases;
                  });
                  await _persistRoomConfiguration();
                }

                if (!mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleExit() async {
    await _stopPreview();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(RoomManagementResult(selectedRoomId: _selectedRoom?.id));
  }

  Future<void> _stopPreview() async {
    _previewAutoStopTimer?.cancel();
    _previewAutoStopTimer = null;
    await _previewPlayer.stop();
    if (!mounted) return;
    setState(() => _currentlyPreviewingPath = null);
  }

  void _startPreviewAutoStopTimer() {
    _previewAutoStopTimer?.cancel();
    _previewAutoStopTimer = Timer(const Duration(seconds: 20), () async {
      await _stopPreview();
    });
  }

  Future<void> _previewTrack(String trackPath) async {
    try {
      // Tap the currently playing preview again to stop it.
      if (_currentlyPreviewingPath == trackPath) {
        await _stopPreview();
        return;
      }

      await _previewPlayer.stop();
      _previewAutoStopTimer?.cancel();

      if (trackPath.startsWith('asset:')) {
        final fullAssetPath = trackPath.substring('asset:'.length);
        final relativePath = fullAssetPath.replaceFirst('assets/', '');
        await _previewPlayer.play(AssetSource(relativePath));
      } else if (trackPath.startsWith('file:')) {
        final filePath = trackPath.substring('file:'.length);
        await _previewPlayer.play(DeviceFileSource(filePath));
      } else {
        await _previewPlayer.play(DeviceFileSource(trackPath));
      }

      await _previewPlayer.setVolume(_volume);
      if (!mounted) return;
      setState(() => _currentlyPreviewingPath = trackPath);
      _startPreviewAutoStopTimer();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot preview track: $error')));
    }
  }

  Future<void> _showAddTrackSheet() async {
    if (!mounted) return;
    final pendingSelections = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = _buildTrackOptions()
                .where((option) => !_selectedTracks.contains(option.path))
                .toList();
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.84,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Track gallery (${options.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final toAdd = pendingSelections
                                  .where(
                                    (path) => !_selectedTracks.contains(path),
                                  )
                                  .toList();
                              if (toAdd.isNotEmpty) {
                                setState(() {
                                  _selectedTracks.addAll(toAdd);
                                });
                                await _persistRoomConfiguration();
                              }
                              await _stopPreview();
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: Text('Add (${pendingSelections.length})'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: options.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 8,
                              childAspectRatio: 3.9,
                            ),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final alreadySelected = _selectedTracks.contains(
                            option.path,
                          );
                          final selected =
                              alreadySelected ||
                              pendingSelections.contains(option.path);
                          final isPlaying =
                              _currentlyPreviewingPath == option.path;
                          return _TrackPreviewChip(
                            title: option.title,
                            durationLabel: _trackDurationLabel(option.path),
                            isPlaying: isPlaying,
                            selected: selected,
                            onPreviewTap: () async {
                              await _previewTrack(option.path);
                              if (!context.mounted) return;
                              setModalState(() {});
                            },
                            onTap: alreadySelected
                                ? null
                                : () {
                                    setModalState(() {
                                      if (pendingSelections.contains(
                                        option.path,
                                      )) {
                                        pendingSelections.remove(option.path);
                                      } else {
                                        pendingSelections.add(option.path);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.upload_file_outlined),
                      title: const Text('Upload from phone files'),
                      subtitle: Text(
                        'Accepted: ${_supportedAudioExtensions.join(', ')}',
                      ),
                      onTap: () async {
                        await _uploadTrackFromFiles();
                        if (!context.mounted) return;
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadTrackFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedAudioExtensions,
    );

    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return;

    final copiedPath = await _copyToAppStorage(
      sourcePath,
      subFolder: 'room_audio',
    );
    final trackKey = 'file:$copiedPath';

    if (_selectedTracks.contains(trackKey)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Track already added')));
      return;
    }

    setState(() => _selectedTracks.add(trackKey));
    await _persistRoomConfiguration();
  }

  Future<void> _showAddVisualSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Add from local album'),
                subtitle: const Text('Select image from gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickVisualFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Upload image or GIF from files'),
                subtitle: Text(
                  'Accepted: ${_supportedVisualExtensions.join(', ')}',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickVisualFromFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickVisualFromGallery() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    final sourcePath = picked?.path;
    if (sourcePath == null) return;
    await _addVisualFromPath(sourcePath);
  }

  Future<void> _pickVisualFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedVisualExtensions,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return;
    await _addVisualFromPath(sourcePath);
  }

  Future<void> _addVisualFromPath(String sourcePath) async {
    final extension = _extensionOf(sourcePath).toLowerCase();
    if (!_supportedVisualExtensions.contains(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unsupported visual format .$extension. Allowed: ${_supportedVisualExtensions.join(', ')}',
          ),
        ),
      );
      return;
    }

    final copiedPath = await _copyToAppStorage(
      sourcePath,
      subFolder: 'room_visuals',
    );

    if (_selectedVisuals.any((visual) => visual.path == copiedPath)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Visual already added')));
      return;
    }

    setState(() {
      _selectedVisuals.add(
        RoomVisualConfig(path: copiedPath, isGif: extension == 'gif'),
      );
    });
    await _persistRoomConfiguration();
  }

  Future<String> _copyToAppStorage(
    String sourcePath, {
    required String subFolder,
  }) async {
    final sourceFile = File(sourcePath);
    final extension = _extensionOf(sourcePath);
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/$subFolder');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetPath =
        '${targetDir.path}/${DateTime.now().millisecondsSinceEpoch}.${extension.isEmpty ? "bin" : extension}';
    final copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  Future<void> _openVisualPopup(RoomVisualConfig visual) async {
    double selectedSpeed = visual.gifSpeed;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: visual.isGif
                          ? SizedBox(
                              height: 240,
                              child: _SpeedControlledGif(
                                sourcePath: visual.path,
                                isAssetReference: _isAssetReference(
                                  visual.path,
                                ),
                                speed: selectedSpeed,
                                fit: BoxFit.contain,
                                errorChild: const SizedBox(
                                  height: 140,
                                  child: Center(
                                    child: Text('Unable to preview image'),
                                  ),
                                ),
                              ),
                            )
                          : Image(
                              image: _visualImageProvider(visual),
                              height: 240,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  height: 140,
                                  child: Center(
                                    child: Text('Unable to preview image'),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      visual.isGif ? 'GIF playback speed' : '',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    if (visual.isGif) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _gifSpeedOptions.map((speed) {
                          return ChoiceChip(
                            label: Text(
                              'x${_speedLabel(speed)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: speed == selectedSpeed,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) {
                              setDialogState(() => selectedSpeed = speed);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (visual.isGif)
                  ElevatedButton(
                    onPressed: () async {
                      final index = _selectedVisuals.indexWhere(
                        (item) => item.path == visual.path,
                      );
                      if (index >= 0) {
                        setState(() {
                          _selectedVisuals[index] = _selectedVisuals[index]
                              .copyWith(gifSpeed: selectedSpeed);
                        });
                        await _persistRoomConfiguration();
                      }
                      if (!mounted) return;
                      Navigator.of(this.context).pop();
                    },
                    child: const Text('Save speed'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<_TrackOption> _buildTrackOptions() {
    final builtin = _builtinTracks.map((track) {
      return _TrackOption(
        title: track.title,
        subtitle: 'Built-in • ${track.author}',
        path: 'asset:${track.fullPath}',
        isBuiltin: true,
      );
    });

    final library = _libraryTracks.map((audio) {
      return _TrackOption(
        title: audio.title ?? audio.fileName,
        subtitle: 'Library • ${audio.durationFormatted}',
        path: 'file:${audio.filePath}',
        isBuiltin: false,
      );
    });
    final options = [...builtin, ...library];
    final knownPaths = options.map((item) => item.path).toSet();
    for (final path in _selectedTracks) {
      if (!path.startsWith('file:') || knownPaths.contains(path)) {
        continue;
      }
      options.add(
        _TrackOption(
          title: _trackName(path),
          subtitle: 'Uploaded • Local file',
          path: path,
          isBuiltin: false,
        ),
      );
      knownPaths.add(path);
    }

    return options;
  }

  String _trackName(String trackPath) {
    if (trackPath.startsWith('asset:')) {
      final clean = trackPath.substring('asset:'.length);
      return clean.split('/').last;
    }
    if (trackPath.startsWith('file:')) {
      final clean = trackPath.substring('file:'.length);
      return clean.split(Platform.pathSeparator).last;
    }
    return trackPath.split(Platform.pathSeparator).last;
  }

  int _trackDurationSeconds(String trackPath) {
    if (trackPath.startsWith('asset:')) {
      final fullPath = trackPath.substring('asset:'.length);
      for (final track in _builtinTracks) {
        if (track.fullPath == fullPath) {
          return _parseDurationToSeconds(track.duration);
        }
      }
    } else if (trackPath.startsWith('file:')) {
      final filePath = trackPath.substring('file:'.length);
      for (final track in _libraryTracks) {
        if (track.filePath == filePath) {
          return track.durationMs ~/ 1000;
        }
      }
    }
    return 0;
  }

  String _trackDurationLabel(String trackPath) {
    final totalSeconds = _trackDurationSeconds(trackPath);
    if (totalSeconds <= 0) return '--:--';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _parseDurationToSeconds(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return (minutes * 60) + seconds;
  }

  String _tracksAggregateSummary() {
    final totalSeconds = _selectedTracks.fold<int>(
      0,
      (sum, trackPath) => sum + _trackDurationSeconds(trackPath),
    );
    final totalMinutes = (totalSeconds / 60).round();
    final trackCount = _selectedTracks.length;
    return '$trackCount tracks • $totalMinutes min total';
  }

  String _extensionOf(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot + 1);
  }

  bool _isAssetReference(String path) => path.startsWith('asset:');

  String _resolveAssetPath(String referencePath) {
    if (_isAssetReference(referencePath)) {
      return referencePath.substring('asset:'.length);
    }
    return referencePath;
  }

  ImageProvider _visualImageProvider(RoomVisualConfig visual) {
    if (_isAssetReference(visual.path)) {
      return AssetImage(_resolveAssetPath(visual.path));
    }
    return FileImage(File(visual.path));
  }

  String _roomKeyFor(RoomModel? room) => room?.id ?? _randomRoomKey;

  List<String> _phrasesForRoom(RoomModel? room) {
    return _roomPhrasesByKey[_roomKeyFor(room)] ?? const [];
  }

  Widget _buildRoomCardVisual(RoomModel? room) {
    String? imageAssetPath;
    if (room?.iconAssetPath != null && room!.iconAssetPath!.isNotEmpty) {
      imageAssetPath = room.iconAssetPath;
    } else if (room?.id == _spaceRoomId) {
      imageAssetPath = _spaceIconAsset;
    } else if (room?.id == _mansionRoomId) {
      imageAssetPath = _mansionIconAsset;
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade500, width: 1.5),
        color: Colors.black.withValues(alpha: 0.03),
      ),
      child: imageAssetPath == null
          ? Icon(Icons.meeting_room_outlined, color: Colors.grey.shade700)
          : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imageAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey.shade700,
                  );
                },
              ),
            ),
    );
  }

  _RoomInfo _roomInfo(RoomModel? room) {
    if (room == null) {
      return const _RoomInfo(
        title: 'Random Room',
        description:
            'No specific room selected. App can play any available random audio.',
      );
    }

    if (room.id == _spaceRoomId) {
      return const _RoomInfo(
        title: 'Space Station Study',
        description:
            'Calm orbital ambience for deep focus. Perfect for long concentration blocks.',
        assetIconPath: _spaceIconAsset,
        isGifIcon: false,
      );
    }

    if (room.id == _mansionRoomId) {
      return const _RoomInfo(
        title: 'Abandoned Mansion Study',
        description:
            'Quiet eerie atmosphere with moody visuals for late-night study sessions.',
        assetIconPath: _mansionIconAsset,
        isGifIcon: true,
      );
    }

    return _RoomInfo(
      title: room.name,
      description: room.description ?? 'Custom room configuration.',
      assetIconPath: room.iconAssetPath,
      isGifIcon: room.iconAssetPath?.toLowerCase().endsWith('.gif') == true,
    );
  }

  double _levelToVolume(int level) {
    return (_basePreviewVolume * level).clamp(0.0, 1.0);
  }

  int _volumeToLevel(double volume) {
    const levels = [1, 2, 3];
    int best = 1;
    double bestDistance = double.infinity;
    for (final level in levels) {
      final distance = (_levelToVolume(level) - volume).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = level;
      }
    }
    return best;
  }

  Future<void> _setVolumeLevel(int level) async {
    final newLevel = level.clamp(1, 3);
    final newVolume = _levelToVolume(newLevel);
    setState(() {
      _volumeLevel = newLevel;
      _volume = newVolume;
    });
    await _previewPlayer.setVolume(newVolume);
    await _persistRoomConfiguration();
  }

  Future<void> _showRoomInfoModal(RoomModel? room) async {
    final info = _roomInfo(room);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogWidth = MediaQuery.of(context).size.width * 0.9;
        final imageWidth = (dialogWidth - 48).clamp(200.0, 640.0);
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(info.title)),
              if (room != null)
                IconButton(
                  tooltip: 'Edit room info',
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _showEditRoomInfoDialog(room);
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          content: _buildRoomDialogContent(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.assetIconPath != null) ...[
                  SizedBox(
                    width: imageWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        info.assetIconPath!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(info.description),
                if (_roomPhrases.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Phrases',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ..._roomPhrases.map(
                    (phrase) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(phrase)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (info.isGifIcon) ...[
                  const SizedBox(height: 8),
                  Text(
                    'GIF visual supports speed controls in Visuals section.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditRoomInfoDialog(RoomModel room) async {
    final titleController = TextEditingController(text: room.name);
    final descriptionController = TextEditingController(
      text: room.description ?? '',
    );
    final phrasesController = TextEditingController(
      text: _roomPhrases.join('\n'),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Room Info'),
          content: _buildRoomDialogContent(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phrasesController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Phrases (one per line)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title cannot be empty')),
                  );
                  return;
                }

                final description = descriptionController.text.trim();
                final phrases = phrasesController.text
                    .split('\n')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();

                room.name = title;
                room.description = description.isEmpty ? null : description;
                await _upsertRoom(room);

                setState(() {
                  _roomPhrases = phrases;
                });
                await _persistRoomConfiguration();

                if (!mounted) return;
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static const List<double> _gifSpeedOptions = [0.2, 0.5, 1.0, 1.5, 2.0];
  String _speedLabel(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleExit();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Management'),
          actions: [
            IconButton(
              tooltip: 'Exit room management',
              onPressed: _handleExit,
              icon: const Icon(Icons.exit_to_app),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRoomSelectionCard(),
                    const SizedBox(height: 16),
                    _buildTracksCard(),
                    const SizedBox(height: 16),
                    _buildVisualsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRoomSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 124,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: _rooms.length + 1,
                    controller: _roomPageController,
                    onPageChanged: (index) async {
                      final room = index == 0 ? null : _rooms[index - 1];
                      await _selectRoom(room, centerCard: false);
                    },
                    itemBuilder: (context, index) {
                      final room = index == 0 ? null : _rooms[index - 1];
                      final selected =
                          room?.id == _selectedRoom?.id ||
                          (room == null && _selectedRoom == null);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final alreadySelected =
                                (room?.id == _selectedRoom?.id) ||
                                (room == null && _selectedRoom == null);
                            if (alreadySelected) {
                              await _centerSelectedRoomCard(room);
                              await _showRoomInfoModal(room);
                              return;
                            }
                            await _selectRoom(room);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade400,
                                width: selected ? 2 : 1,
                              ),
                              color: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildRoomCardVisual(room),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final phrases = _phrasesForRoom(room);
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            room?.name ?? 'Random',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (phrases.isNotEmpty) ...[
                                            Text(
                                              phrases.first,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (phrases.length > 1)
                                              Text(
                                                phrases[1],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                  fontSize: 13,
                                                ),
                                              ),
                                          ] else
                                            Text(
                                              room == null
                                                  ? 'Random audio fallback'
                                                  : (room.description ??
                                                        'No phrases yet'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
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
                  ),
                  Positioned(
                    top: 0,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _selectRandomSpecificRoom,
                              child: const Icon(
                                Icons.casino_outlined,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async => _selectRoom(null),
                              child: const Icon(
                                Icons.meeting_room_outlined,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _showCreateRoomDialog,
                              child: const Icon(Icons.add, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: List.generate(_rooms.length + 1, (index) {
                              final room = index == 0
                                  ? null
                                  : _rooms[index - 1];
                              final selected =
                                  (room?.id == _selectedRoom?.id) ||
                                  (room == null && _selectedRoom == null);
                              return GestureDetector(
                                onTap: () async => _selectRoom(room),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  width: 12,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Colors.grey.shade600,
                                      width: 1.5,
                                    ),
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Volume',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final level = index + 1;
                        final selected = _volumeLevel >= level;
                        return Padding(
                          padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                          child: GestureDetector(
                            onTap: () async => _setVolumeLevel(level),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 12,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: Colors.grey.shade600,
                                  width: 1.5,
                                ),
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracksCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_music_outlined),
                const SizedBox(width: 8),
                Text('Tracks', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${_selectedTracks.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _isTracksExpanded ? 'Hide tracks' : 'View tracks',
                  onPressed: () {
                    setState(() {
                      _isTracksExpanded = !_isTracksExpanded;
                    });
                  },
                  icon: Icon(
                    _isTracksExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddTrackSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (!_isTracksExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    _tracksAggregateSummary(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
              )
            else if (_selectedTracks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No tracks added yet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedTracks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 6,
                  childAspectRatio: 4.6,
                ),
                itemBuilder: (context, index) {
                  final track = _selectedTracks[index];
                  final isPlaying = _currentlyPreviewingPath == track;
                  return _TrackPreviewChip(
                    title: _trackName(track),
                    durationLabel: _trackDurationLabel(track),
                    isPlaying: isPlaying,
                    onPreviewTap: () => _previewTrack(track),
                    onTap: () => _previewTrack(track),
                    onRemoveTap: () async {
                      setState(() {
                        _selectedTracks.removeAt(index);
                      });
                      await _persistRoomConfiguration();
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualsCard() {
    final visualsWithAddTileCount = _selectedVisuals.length + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined),
                const SizedBox(width: 8),
                Text('Visuals', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${_selectedVisuals.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _isVisualsExpanded ? 'Hide visuals' : 'View visuals',
                  onPressed: () {
                    setState(() {
                      _isVisualsExpanded = !_isVisualsExpanded;
                    });
                  },
                  icon: Icon(
                    _isVisualsExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddVisualSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (!_isVisualsExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    '${_selectedVisuals.length} visuals',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
              )
            else if (_selectedVisuals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No visuals added yet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visualsWithAddTileCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  if (index == _selectedVisuals.length) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showAddVisualSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade500,
                            width: 1.5,
                          ),
                        ),
                        child: const Center(child: Icon(Icons.add, size: 22)),
                      ),
                    );
                  }

                  final visual = _selectedVisuals[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openVisualPopup(visual),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: visual.isGif
                                ? _SpeedControlledGif(
                                    sourcePath: visual.path,
                                    isAssetReference: _isAssetReference(
                                      visual.path,
                                    ),
                                    speed: visual.gifSpeed,
                                    fit: BoxFit.cover,
                                    errorChild: Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                  )
                                : Image(
                                    image: _visualImageProvider(visual),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        if (visual.isGif)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GIF x${_speedLabel(visual.gifSpeed)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                setState(() {
                                  _selectedVisuals.removeAt(index);
                                });
                                await _persistRoomConfiguration();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _currentPageForSelectedRoom() {
    if (_selectedRoom == null) return 0;
    final index = _rooms.indexWhere((item) => item.id == _selectedRoom?.id);
    return index < 0 ? 0 : index + 1;
  }
}

class _SpeedControlledGif extends StatefulWidget {
  final String sourcePath;
  final bool isAssetReference;
  final double speed;
  final BoxFit fit;
  final Widget? errorChild;

  const _SpeedControlledGif({
    required this.sourcePath,
    required this.isAssetReference,
    required this.speed,
    this.fit = BoxFit.contain,
    this.errorChild,
  });

  @override
  State<_SpeedControlledGif> createState() => _SpeedControlledGifState();
}

class _SpeedControlledGifState extends State<_SpeedControlledGif> {
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
  void didUpdateWidget(covariant _SpeedControlledGif oldWidget) {
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
    if (widget.speed != oldWidget.speed && _frames.isNotEmpty) {
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
      _scheduleNextFrame();
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
    final filePath = widget.sourcePath.startsWith('file:')
        ? widget.sourcePath.substring('file:'.length)
        : widget.sourcePath;
    return File(filePath).readAsBytes();
  }

  void _scheduleNextFrame() {
    _frameTimer?.cancel();
    if (!mounted || _frames.length <= 1) return;
    final current = _frames[_frameIndex];
    final baseMs = current.duration.inMilliseconds <= 0
        ? 100
        : current.duration.inMilliseconds;
    final speed = widget.speed <= 0 ? 1.0 : widget.speed;
    final adjustedMs = max(16, (baseMs / speed).round());
    _frameTimer = Timer(Duration(milliseconds: adjustedMs), () {
      if (!mounted || _frames.isEmpty) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });
      _scheduleNextFrame();
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    for (final frame in _frames) {
      frame.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _frames.isEmpty) {
      return widget.errorChild ?? const SizedBox.shrink();
    }
    return RawImage(image: _frames[_frameIndex].image, fit: widget.fit);
  }
}

class _TrackOption {
  final String title;
  final String subtitle;
  final String path;
  final bool isBuiltin;

  const _TrackOption({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.isBuiltin,
  });
}

class _TrackPreviewChip extends StatelessWidget {
  final String title;
  final String durationLabel;
  final bool isPlaying;
  final bool selected;
  final VoidCallback onPreviewTap;
  final VoidCallback? onTap;
  final Future<void> Function()? onRemoveTap;

  const _TrackPreviewChip({
    required this.title,
    required this.durationLabel,
    required this.isPlaying,
    required this.onPreviewTap,
    this.selected = false,
    this.onTap,
    this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? Colors.grey.shade900 : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: isPlaying ? 'Stop preview' : 'Preview (20s max)',
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: onPreviewTap,
              icon: Icon(
                isPlaying ? Icons.graphic_eq : Icons.play_arrow,
                size: 16,
                color: isPlaying ? Colors.green : null,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              durationLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
            if (onRemoveTap != null) ...[
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Remove track',
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () async => onRemoveTap!.call(),
                icon: const Icon(Icons.delete_outline, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomInfo {
  final String title;
  final String description;
  final String? assetIconPath;
  final bool isGifIcon;

  const _RoomInfo({
    required this.title,
    required this.description,
    this.assetIconPath,
    this.isGifIcon = false,
  });
}

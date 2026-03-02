import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/lofi_track.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

class RoomManagementResult {
  final String? selectedProjectId;

  const RoomManagementResult({required this.selectedProjectId});
}

class RoomManagementScreen extends StatefulWidget {
  final List<ProjectModel> projects;
  final ProjectModel? selectedProject;

  const RoomManagementScreen({
    super.key,
    required this.projects,
    required this.selectedProject,
  });

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  static const String _boxName = 'roomManagement';
  static const String _randomRoomKey = '__random__';
  static const String _spaceRoomId = 'sample-room-space-station-study';
  static const String _mansionRoomId = 'sample-room-abandoned-mansion-study';
  static const String _spaceIconAsset = 'assets/album/al16-spaceship.png';
  static const String _mansionIconAsset =
      'assets/album/an02_model1_working_2.gif';
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

  ProjectModel? _selectedRoom;
  double _volume = 0.7;
  List<String> _selectedTracks = [];
  List<RoomVisualConfig> _selectedVisuals = [];
  List<LofiTrack> _builtinTracks = [];
  List<EnhancedAudioModel> _libraryTracks = [];
  bool _isLoading = true;
  String? _currentlyPreviewingPath;
  Timer? _previewAutoStopTimer;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.selectedProject;
    _loadRoomContext();
  }

  @override
  void dispose() {
    _previewAutoStopTimer?.cancel();
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

  Future<void> _loadRoomContext() async {
    setState(() => _isLoading = true);
    try {
      _builtinTracks = await LofiService.getAllTracks();
      final audioBox = Hive.box<EnhancedAudioModel>('audioFiles');
      _libraryTracks = audioBox.values.toList();
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
        _volume = model.volume.clamp(0.0, 1.0);
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedTracks = [];
      _selectedVisuals = [];
      _volume = 0.7;
    });
  }

  Future<void> _persistRoomConfiguration() async {
    final box = await _openRoomBox();
    final model = RoomManagementModel(
      selectedTracks: _selectedTracks,
      selectedVisuals: _selectedVisuals,
      volume: _volume,
    );
    await box.put(_roomStorageKey, model.toMap());
  }

  Future<void> _selectRoom(ProjectModel? room) async {
    setState(() {
      _selectedRoom = room;
    });
    await _loadRoomConfiguration();
  }

  Future<void> _handleExit() async {
    await _previewPlayer.stop();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(RoomManagementResult(selectedProjectId: _selectedRoom?.id));
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('Add from existing audios'),
                subtitle: const Text('Only tracks not selected yet are shown'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showExistingTrackPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Upload from phone files'),
                subtitle: Text(
                  'Accepted: ${_supportedAudioExtensions.join(', ')}',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _uploadTrackFromFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExistingTrackPicker() async {
    final options = _buildTrackOptions()
        .where((option) => !_selectedTracks.contains(option.path))
        .toList();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining existing tracks to add')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Track'),
          content: SizedBox(
            width: 500,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  leading: Icon(
                    option.isBuiltin ? Icons.music_note : Icons.mic,
                    color: option.isBuiltin ? Colors.deepPurple : Colors.blue,
                  ),
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  trailing: const Icon(Icons.add),
                  onTap: () async {
                    Navigator.of(context).pop();
                    setState(() => _selectedTracks.add(option.path));
                    await _persistRoomConfiguration();
                  },
                );
              },
            ),
          ),
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
              title: const Text('Visual Preview'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
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
                      visual.isGif
                          ? 'GIF playback speed'
                          : 'Static image (no speed controls)',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    if (visual.isGif) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _gifSpeedOptions.map((speed) {
                          return ChoiceChip(
                            label: Text('x${_speedLabel(speed)}'),
                            selected: speed == selectedSpeed,
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

    return [...builtin, ...library];
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

  _RoomInfo _roomInfo(ProjectModel? room) {
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
    );
  }

  Future<void> _showRoomInfoModal(ProjectModel? room) async {
    final info = _roomInfo(room);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogMaxWidth = MediaQuery.of(context).size.width * 0.7;
        final imageWidth = dialogMaxWidth.clamp(180.0, 280.0);
        return AlertDialog(
          title: Text(info.title),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: imageWidth),
            child: Column(
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
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
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

  static const List<double> _gifSpeedOptions = [0.2, 0.5, 1.0, 1.5, 2.0];
  String _speedLabel(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildRoomSelectionCard() {
    final roomName = _selectedRoom?.name ?? 'Random Room';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.meeting_room_outlined),
                const SizedBox(width: 8),
                Text(
                  roomName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe to change room. Tap any room card to open that room info modal.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 124,
              child: PageView.builder(
                itemCount: widget.projects.length + 1,
                controller: PageController(
                  viewportFraction: 0.78,
                  initialPage: _currentPageForSelectedRoom(),
                ),
                onPageChanged: (index) async {
                  final room = index == 0 ? null : widget.projects[index - 1];
                  await _selectRoom(room);
                },
                itemBuilder: (context, index) {
                  final room = index == 0 ? null : widget.projects[index - 1];
                  final selected =
                      room?.id == _selectedRoom?.id ||
                      (room == null && _selectedRoom == null);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await _selectRoom(room);
                        await _showRoomInfoModal(room);
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (room?.id == _spaceRoomId ||
                                room?.id == _mansionRoomId) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  room?.id == _spaceRoomId
                                      ? _spaceIconAsset
                                      : _mansionIconAsset,
                                  height: 42,
                                  width: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              room?.name ?? 'Random',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              room == null
                                  ? 'Random audio fallback'
                                  : 'Tap for room details',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Random'),
                  selected: _selectedRoom == null,
                  onSelected: (_) async => _selectRoom(null),
                ),
                ...widget.projects.map((project) {
                  return ChoiceChip(
                    label: Text(project.name),
                    selected: _selectedRoom?.id == project.id,
                    onSelected: (_) async => _selectRoom(project),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Text('Volume', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _volume,
              onChanged: (value) async {
                setState(() => _volume = value);
                await _previewPlayer.setVolume(value);
                await _persistRoomConfiguration();
              },
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
                TextButton.icon(
                  onPressed: _showAddTrackSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_selectedTracks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No tracks added yet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedTracks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final track = _selectedTracks[index];
                  final isPlaying = _currentlyPreviewingPath == track;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: Colors.grey.withValues(alpha: 0.08),
                    leading: Icon(
                      isPlaying ? Icons.graphic_eq : Icons.play_arrow,
                      color: isPlaying ? Colors.green : null,
                    ),
                    title: Text(
                      _trackName(track),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.startsWith('asset:')
                          ? 'Built-in audio'
                          : 'File audio',
                    ),
                    onTap: () => _previewTrack(track),
                    trailing: IconButton(
                      tooltip: 'Remove track',
                      onPressed: () async {
                        setState(() {
                          _selectedTracks.removeAt(index);
                        });
                        await _persistRoomConfiguration();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualsCard() {
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
                TextButton.icon(
                  onPressed: _showAddVisualSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_selectedVisuals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No visuals added yet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedVisuals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final visual = _selectedVisuals[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openVisualPopup(visual),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(
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
        ),
      ),
    );
  }

  int _currentPageForSelectedRoom() {
    if (_selectedRoom == null) return 0;
    final index = widget.projects.indexWhere((p) => p.id == _selectedRoom?.id);
    return index < 0 ? 0 : index + 1;
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

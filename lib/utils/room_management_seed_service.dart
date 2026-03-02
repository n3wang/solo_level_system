import 'package:hive/hive.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

class RoomManagementSeedService {
  static const String _roomManagementBoxName = 'roomManagement';
  static const String _spaceRoomId = 'sample-room-space-station-study';
  static const String _mansionRoomId = 'sample-room-abandoned-mansion-study';
  static const String _spaceVisualAsset =
      'asset:assets/album/al16-spaceship.png';
  static const String _mansionVisualAsset =
      'asset:assets/album/an02_model1_working_2.gif';

  static Future<void> ensureSampleRooms() async {
    if (!Hive.isBoxOpen('projects')) {
      await Hive.openBox<ProjectModel>('projects');
    }
    final projectsBox = Hive.box<ProjectModel>('projects');

    final allProjects = projectsBox.values.toList();

    final hasSpaceRoom = allProjects.any((p) => p.id == _spaceRoomId);
    final hasMansionRoom = allProjects.any((p) => p.id == _mansionRoomId);

    if (!hasSpaceRoom) {
      final spaceRoom = ProjectModel(
        id: _spaceRoomId,
        name: 'Space Station Study',
        description: 'Quiet orbital room for deep, focused sessions.',
        color: '#3F51B5',
        iconName: 'rocket_launch',
        createdAt: DateTime.now(),
        priority: 2,
      );
      await projectsBox.add(spaceRoom);
    }

    if (!hasMansionRoom) {
      final mansionRoom = ProjectModel(
        id: _mansionRoomId,
        name: 'Abandoned Mansion Study',
        description: 'Dusty, moody room for atmospheric study sessions.',
        color: '#5D4037',
        iconName: 'nightlight_round',
        createdAt: DateTime.now(),
        priority: 3,
      );
      await projectsBox.add(mansionRoom);
    }

    await _seedDefaultRoomTracksIfMissing();
  }

  static Future<void> _seedDefaultRoomTracksIfMissing() async {
    final tracks = await LofiService.getAllTracks();
    if (tracks.isEmpty) return;

    final spaceTracks = tracks
        .where((t) => t.id >= 1 && t.id <= 8)
        .map((t) => 'asset:${t.fullPath}')
        .toList();

    final mansionTracks = tracks
        .where((t) => t.id >= 30 && t.id <= 38)
        .map((t) => 'asset:${t.fullPath}')
        .toList();

    final roomBox = Hive.isBoxOpen(_roomManagementBoxName)
        ? Hive.box(_roomManagementBoxName)
        : await Hive.openBox(_roomManagementBoxName);

    if (roomBox.get(_spaceRoomId) == null) {
      final spaceModel = RoomManagementModel(
        selectedTracks: spaceTracks,
        selectedVisuals: const [
          RoomVisualConfig(
            path: _spaceVisualAsset,
            isGif: false,
            gifSpeed: 1.0,
          ),
        ],
        volume: 0.70,
      );
      await roomBox.put(_spaceRoomId, spaceModel.toMap());
    } else {
      final raw = roomBox.get(_spaceRoomId);
      if (raw is Map) {
        final model = RoomManagementModel.fromMap(raw);
        final hasSpaceVisual = model.selectedVisuals.any(
          (v) => v.path == _spaceVisualAsset,
        );
        if (!hasSpaceVisual) {
          final updated = RoomManagementModel(
            selectedTracks: model.selectedTracks,
            selectedVisuals: [
              ...model.selectedVisuals,
              const RoomVisualConfig(
                path: _spaceVisualAsset,
                isGif: false,
                gifSpeed: 1.0,
              ),
            ],
            volume: model.volume,
          );
          await roomBox.put(_spaceRoomId, updated.toMap());
        }
      }
    }

    if (roomBox.get(_mansionRoomId) == null) {
      final mansionModel = RoomManagementModel(
        selectedTracks: mansionTracks,
        selectedVisuals: const [
          RoomVisualConfig(
            path: _mansionVisualAsset,
            isGif: true,
            gifSpeed: 1.0,
          ),
        ],
        volume: 0.62,
      );
      await roomBox.put(_mansionRoomId, mansionModel.toMap());
    } else {
      final raw = roomBox.get(_mansionRoomId);
      if (raw is Map) {
        final model = RoomManagementModel.fromMap(raw);
        final hasMansionVisual = model.selectedVisuals.any(
          (v) => v.path == _mansionVisualAsset,
        );
        if (!hasMansionVisual) {
          final updated = RoomManagementModel(
            selectedTracks: model.selectedTracks,
            selectedVisuals: [
              ...model.selectedVisuals,
              const RoomVisualConfig(
                path: _mansionVisualAsset,
                isGif: true,
                gifSpeed: 1.0,
              ),
            ],
            volume: model.volume,
          );
          await roomBox.put(_mansionRoomId, updated.toMap());
        }
      }
    }
  }
}

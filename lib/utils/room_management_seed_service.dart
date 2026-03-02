import 'package:hive/hive.dart';
import 'package:solo_level_system/models/room_model.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

class RoomManagementSeedService {
  static const String _roomsBoxName = 'rooms';
  static const String _roomManagementBoxName = 'roomManagement';
  static const String _spaceRoomId = 'sample-room-space-station-study';
  static const String _mansionRoomId = 'sample-room-abandoned-mansion-study';
  static const String _spaceVisualAsset =
      'asset:assets/album/al16-spaceship.png';
  static const String _mansionVisualAsset =
      'asset:assets/album/an02_model1_working_2.gif';
  static const List<String> _spacePhrases = [
    'Steady orbit, steady focus.',
    'One module at a time.',
    'Small progress keeps the mission alive.',
    'Breathe, align, continue.',
  ];
  static const List<String> _mansionPhrases = [
    'Quiet halls, sharp mind.',
    'Let the silence carry your focus.',
    'Slow steps, deep concentration.',
    'Finish this room, then the next.',
  ];

  static Future<void> ensureSampleRooms() async {
    if (!Hive.isBoxOpen(_roomsBoxName)) {
      await Hive.openBox(_roomsBoxName);
    }
    final roomsBox = Hive.box(_roomsBoxName);

    final allRooms = roomsBox.values
        .whereType<Map>()
        .map(RoomModel.fromMap)
        .toList();

    final hasSpaceRoom = allRooms.any((room) => room.id == _spaceRoomId);
    final hasMansionRoom = allRooms.any((room) => room.id == _mansionRoomId);

    if (!hasSpaceRoom) {
      final spaceRoom = RoomModel(
        id: _spaceRoomId,
        name: 'Space Station Study',
        description: 'Quiet orbital room for deep, focused sessions.',
        iconAssetPath: 'assets/album/al16-spaceship.png',
      );
      await roomsBox.put(spaceRoom.id, spaceRoom.toMap());
    }

    if (!hasMansionRoom) {
      final mansionRoom = RoomModel(
        id: _mansionRoomId,
        name: 'Abandoned Mansion Study',
        description: 'Dusty, moody room for atmospheric study sessions.',
        iconAssetPath: 'assets/album/an02_model1_working_2.gif',
      );
      await roomsBox.put(mansionRoom.id, mansionRoom.toMap());
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
        phrases: _spacePhrases,
      );
      await roomBox.put(_spaceRoomId, spaceModel.toMap());
    } else {
      final raw = roomBox.get(_spaceRoomId);
      if (raw is Map) {
        final model = RoomManagementModel.fromMap(raw);
        final hasSpaceVisual = model.selectedVisuals.any(
          (v) => v.path == _spaceVisualAsset,
        );
        final shouldSeedPhrases = model.phrases.isEmpty;
        if (!hasSpaceVisual || shouldSeedPhrases) {
          final updated = RoomManagementModel(
            selectedTracks: model.selectedTracks,
            selectedVisuals: [
              ...model.selectedVisuals,
              if (!hasSpaceVisual)
                const RoomVisualConfig(
                  path: _spaceVisualAsset,
                  isGif: false,
                  gifSpeed: 1.0,
                ),
            ],
            volume: model.volume,
            phrases: shouldSeedPhrases ? _spacePhrases : model.phrases,
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
        phrases: _mansionPhrases,
      );
      await roomBox.put(_mansionRoomId, mansionModel.toMap());
    } else {
      final raw = roomBox.get(_mansionRoomId);
      if (raw is Map) {
        final model = RoomManagementModel.fromMap(raw);
        final hasMansionVisual = model.selectedVisuals.any(
          (v) => v.path == _mansionVisualAsset,
        );
        final shouldSeedPhrases = model.phrases.isEmpty;
        if (!hasMansionVisual || shouldSeedPhrases) {
          final updated = RoomManagementModel(
            selectedTracks: model.selectedTracks,
            selectedVisuals: [
              ...model.selectedVisuals,
              if (!hasMansionVisual)
                const RoomVisualConfig(
                  path: _mansionVisualAsset,
                  isGif: true,
                  gifSpeed: 1.0,
                ),
            ],
            volume: model.volume,
            phrases: shouldSeedPhrases ? _mansionPhrases : model.phrases,
          );
          await roomBox.put(_mansionRoomId, updated.toMap());
        }
      }
    }
  }
}

import 'package:hive/hive.dart';

import 'package:solo_level_system/models/lofi_track.dart';
import 'package:solo_level_system/models/room_management_model.dart';
import 'package:solo_level_system/models/room_model.dart';
import 'package:solo_level_system/utils/lofi_service.dart';

/// Seeds preconfigured lofi rooms (tracks by filename prefix, bundled album GIFs).
///
/// Idempotent: only fills empty [RoomManagementModel] fields so user edits win.
class RoomManagementSeedService {
  RoomManagementSeedService._();

  static const String _roomsBoxName = 'rooms';
  static const String _roomMgmtBoxName = 'roomManagement';

  static Future<void> ensureSampleRooms() async {
    final allTracks = await LofiService.getAllTracks();
    if (allTracks.isEmpty) return;

    if (!Hive.isBoxOpen(_roomsBoxName)) {
      await Hive.openBox(_roomsBoxName);
    }
    if (!Hive.isBoxOpen(_roomMgmtBoxName)) {
      await Hive.openBox(_roomMgmtBoxName);
    }

    final roomsBox = Hive.box(_roomsBoxName);
    final mgmtBox = Hive.box(_roomMgmtBoxName);

    for (final pack in _hardcodedRooms) {
      await _applyPack(
        pack: pack,
        allTracks: allTracks,
        roomsBox: roomsBox,
        mgmtBox: mgmtBox,
      );
    }
  }

  static Future<void> _applyPack({
    required _HardcodedRoomPack pack,
    required List<LofiTrack> allTracks,
    required Box<dynamic> roomsBox,
    required Box<dynamic> mgmtBox,
  }) async {
    final existingRoomRaw = roomsBox.get(pack.id);
    final room =
        existingRoomRaw is Map
            ? RoomModel.fromMap(existingRoomRaw)
            : RoomModel(
                id: pack.id,
                name: pack.name,
                description: pack.description,
                isActive: true,
              );
    await roomsBox.put(pack.id, room.toMap());

    final existingMgmtRaw = mgmtBox.get(pack.id);
    final previous =
        existingMgmtRaw is Map
            ? RoomManagementModel.fromMap(existingMgmtRaw)
            : const RoomManagementModel();

    final matchedTracks = _tracksForPack(pack, allTracks);
    final trackRefs =
        matchedTracks
            .map((t) => _assetRefForTrack(t))
            .toList(growable: false);

    final hasPersistedTracks =
        previous.selectedTracks.any((t) => t.trim().isNotEmpty);
    final nextTracks = hasPersistedTracks ? previous.selectedTracks : trackRefs;

    final safeTracks =
        nextTracks.where((t) => t.trim().isNotEmpty).toList(growable: false);
    final resolvedTracks =
        safeTracks.isEmpty
            ? [
              _assetRefForTrack(
                matchedTracks.isNotEmpty ? matchedTracks.first : allTracks.first,
              ),
            ]
            : safeTracks;

    final nextVisuals =
        previous.selectedVisuals.isNotEmpty
            ? previous.selectedVisuals
            : pack.visuals;

    final nextPhrases =
        previous.phrases.isNotEmpty ? previous.phrases : pack.phrases;

    final merged = RoomManagementModel(
      selectedTracks: resolvedTracks,
      selectedVisuals: nextVisuals,
      volume: previous.volume,
      phrases: nextPhrases,
    );
    await mgmtBox.put(pack.id, merged.toMap());
  }

  static List<LofiTrack> _tracksForPack(
    _HardcodedRoomPack pack,
    List<LofiTrack> allTracks,
  ) {
    final out = <LofiTrack>[];
    for (final track in allTracks) {
      final fn = track.filename.toLowerCase();
      if (pack.trackPrefixes.any((p) => fn.startsWith(p.toLowerCase()))) {
        out.add(track);
      }
    }
    out.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename));
    return out;
  }

  static String _assetRefForTrack(LofiTrack t) => 'asset:${t.fullPath}';
}

class _HardcodedRoomPack {
  final String id;
  final String name;
  final String description;
  final List<String> trackPrefixes;
  final List<RoomVisualConfig> visuals;
  final List<String> phrases;

  const _HardcodedRoomPack({
    required this.id,
    required this.name,
    required this.description,
    required this.trackPrefixes,
    required this.visuals,
    required this.phrases,
  });
}

const List<_HardcodedRoomPack> _hardcodedRooms = [
  _HardcodedRoomPack(
    id: 'room_like_a_dog',
    name: 'Like a Dog',
    description: 'Warm, playful lofi.',
    trackPrefixes: ['like_a_dog_'],
    visuals: [
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_1.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_2.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_3.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_4.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_5.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_6.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/like_a_dog_7.gif',
        isGif: true,
      ),
    ],
    phrases: [
      'Stretch, breathe, one more rep.',
      'You showed up — that already counts.',
    ],
  ),
  _HardcodedRoomPack(
    id: 'room_ghost_lofis',
    name: 'Ghost Lofis',
    description: 'Soft haunted vibes.',
    trackPrefixes: ['ghost_lofi_'],
    visuals: [
      RoomVisualConfig(
        path: 'asset:assets/images/album/ghost_lofi_1.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/ghost_lofi_2.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/ghost_lofi_3.gif',
        isGif: true,
      ),
      RoomVisualConfig(
        path: 'asset:assets/images/album/ghost_lofi_4.gif',
        isGif: true,
      ),
    ],
    phrases: [
      'Quiet focus. Steady progress.',
      'Eerie calm — keep the streak.',
    ],
  ),
  _HardcodedRoomPack(
    id: 'room_lab',
    name: 'Lab',
    description: 'Late-night experiment energy.',
    trackPrefixes: ['lab_'],
    visuals: [
      RoomVisualConfig(path: 'asset:assets/images/album/lab_1.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/lab_2.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/lab_3.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/lab_4.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/lab_4.jpg', isGif: false),
    ],
    phrases: [
      'Hypothesis: you finish strong today.',
      'Measure twice, ship once.',
    ],
  ),
  _HardcodedRoomPack(
    id: 'room_90s_jap',
    name: '90s Jap',
    description: 'Retro city pop and neon nights.',
    trackPrefixes: ['90s_jap_', 'kiraisuki'],
    visuals: [
      RoomVisualConfig(path: 'asset:assets/images/album/90s_jap_1.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/90s_jap_2.gif', isGif: true),
      RoomVisualConfig(path: 'asset:assets/images/album/90s_jap_3.gif', isGif: true),
    ],
    phrases: [
      'Neon focus. Vinyl dreams.',
      'Tape hiss and flow state.',
    ],
  ),
];

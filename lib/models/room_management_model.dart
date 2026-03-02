class RoomVisualConfig {
  final String path;
  final bool isGif;
  final double gifSpeed;

  const RoomVisualConfig({
    required this.path,
    required this.isGif,
    this.gifSpeed = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {'path': path, 'isGif': isGif, 'gifSpeed': gifSpeed};
  }

  factory RoomVisualConfig.fromMap(Map<dynamic, dynamic> map) {
    return RoomVisualConfig(
      path: (map['path'] ?? '').toString(),
      isGif: map['isGif'] == true,
      gifSpeed: (map['gifSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  RoomVisualConfig copyWith({String? path, bool? isGif, double? gifSpeed}) {
    return RoomVisualConfig(
      path: path ?? this.path,
      isGif: isGif ?? this.isGif,
      gifSpeed: gifSpeed ?? this.gifSpeed,
    );
  }
}

class RoomManagementModel {
  final List<String> selectedTracks;
  final List<RoomVisualConfig> selectedVisuals;
  final double volume;

  const RoomManagementModel({
    this.selectedTracks = const [],
    this.selectedVisuals = const [],
    this.volume = 0.7,
  });

  Map<String, dynamic> toMap() {
    return {
      'selectedTracks': selectedTracks,
      'selectedVisuals': selectedVisuals.map((item) => item.toMap()).toList(),
      'volume': volume,
    };
  }

  factory RoomManagementModel.fromMap(Map<dynamic, dynamic> map) {
    final visualsRaw = (map['selectedVisuals'] as List?) ?? const [];
    return RoomManagementModel(
      selectedTracks: ((map['selectedTracks'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      selectedVisuals: visualsRaw
          .whereType<Map>()
          .map(RoomVisualConfig.fromMap)
          .toList(),
      volume: (map['volume'] as num?)?.toDouble() ?? 0.7,
    );
  }
}

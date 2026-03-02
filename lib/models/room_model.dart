class RoomModel {
  final String id;
  String name;
  String? description;
  String? iconAssetPath;
  bool isActive;
  DateTime createdAt;

  RoomModel({
    required this.id,
    required this.name,
    this.description,
    this.iconAssetPath,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconAssetPath': iconAssetPath,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RoomModel.fromMap(Map<dynamic, dynamic> map) {
    return RoomModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unnamed Room',
      description: map['description']?.toString(),
      iconAssetPath: map['iconAssetPath']?.toString(),
      isActive: map['isActive'] != false,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

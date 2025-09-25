class LofiTrack {
  final int id;
  final String filename;
  final String originalName;
  final String title;
  final String author;
  final String site;
  final String duration;
  final int fileSize;
  final String? albumImage;

  const LofiTrack({
    required this.id,
    required this.filename,
    required this.originalName,
    required this.title,
    required this.author,
    required this.site,
    required this.duration,
    required this.fileSize,
    this.albumImage,
  });

  factory LofiTrack.fromJson(Map<String, dynamic> json) {
    return LofiTrack(
      id: json['id'] as int,
      filename: json['filename'] as String,
      originalName: json['originalName'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      site: json['site'] as String,
      duration: json['duration'] as String,
      fileSize: json['fileSize'] as int,
      albumImage: json['albumImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'originalName': originalName,
      'title': title,
      'author': author,
      'site': site,
      'duration': duration,
      'fileSize': fileSize,
      'albumImage': albumImage,
    };
  }

  String get fullPath => 'assets/lofi/$filename';
  String? get albumImagePath => albumImage != null ? 'assets/$albumImage' : null;
}

class LofiMapping {
  final String version;
  final String generated;
  final int totalTracks;
  final List<LofiTrack> tracks;

  const LofiMapping({
    required this.version,
    required this.generated,
    required this.totalTracks,
    required this.tracks,
  });

  factory LofiMapping.fromJson(Map<String, dynamic> json) {
    return LofiMapping(
      version: json['version'] as String,
      generated: json['generated'] as String,
      totalTracks: json['total_tracks'] as int,
      tracks: (json['tracks'] as List<dynamic>)
          .map((track) => LofiTrack.fromJson(track as Map<String, dynamic>))
          .toList(),
    );
  }
}
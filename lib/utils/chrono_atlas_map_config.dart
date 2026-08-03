/// Which basemap Chrono Atlas uses.
///
/// Keep [onlineTiles] implemented for later connectivity-based switching.
/// For now [backend] forces the offline shape map.
enum ChronoAtlasMapBackend {
  offlineShape,

  /// OpenStreetMap raster tiles via [MapTileLayer] — needs network.
  onlineTiles,
}

class ChronoAtlasMapConfig {
  ChronoAtlasMapConfig._();

  /// Temporary override: always offline. Change to connectivity-aware later.
  static const bool forceOffline = true;

  static ChronoAtlasMapBackend get backend => forceOffline
      ? ChronoAtlasMapBackend.offlineShape
      : ChronoAtlasMapBackend.onlineTiles;

  static bool get useOfflineShape =>
      backend == ChronoAtlasMapBackend.offlineShape;

  static const String shapeAsset = 'assets/maps/world_countries.geojson';
  static const String shapeDataField = 'NAME';
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

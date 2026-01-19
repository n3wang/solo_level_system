// lib/utils/palette_notifier.dart
import 'package:flutter/foundation.dart';

/// Notifier for palette changes
/// Use this to notify the app when the palette changes so it can rebuild
class PaletteNotifier extends ChangeNotifier {
  static final PaletteNotifier _instance = PaletteNotifier._internal();
  factory PaletteNotifier() => _instance;
  PaletteNotifier._internal();

  String _currentPalette = 'creative';

  String get currentPalette => _currentPalette;

  /// Notify that the palette has changed
  void notifyPaletteChanged(String newPalette) {
    if (_currentPalette != newPalette) {
      _currentPalette = newPalette;
      notifyListeners();
    }
  }
}

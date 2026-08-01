/// How focus sessions grant collectible cards.
enum CardAcquisitionMode {
  /// Drop cards when the work session completes (timing via [CardAcquireTiming]).
  sessionCompletion('session_completion'),

  /// Pick a challenge card for the break; grant after break ends.
  rogue('rogue'),

  /// No card drops from focus sessions.
  disabled('disabled');

  const CardAcquisitionMode(this.wire);
  final String wire;

  static CardAcquisitionMode fromWire(String? raw) {
    switch (raw) {
      case 'rogue':
        return CardAcquisitionMode.rogue;
      case 'disabled':
        return CardAcquisitionMode.disabled;
      case 'session_completion':
      default:
        return CardAcquisitionMode.sessionCompletion;
    }
  }
}

/// When [CardAcquisitionMode.sessionCompletion] grants cards.
enum CardAcquireTiming {
  /// Grant after the break timer finishes (default).
  afterBreak('after_break'),

  /// Grant immediately when the work/focus session finishes.
  afterFocus('after_focus');

  const CardAcquireTiming(this.wire);
  final String wire;

  static CardAcquireTiming fromWire(String? raw) {
    switch (raw) {
      case 'after_focus':
        return CardAcquireTiming.afterFocus;
      case 'after_break':
      default:
        return CardAcquireTiming.afterBreak;
    }
  }
}

/// Defaults for rogue challenge list (always persisted; filtered at runtime).
class RogueChallengeDefaults {
  RogueChallengeDefaults._();

  static const String netflixDevOnly = 'Watch international netflix';

  static const List<String> base = [
    'clean workplace',
    'drink something',
    '10 pushups',
    '20 pushups',
  ];

  static List<String> withDevExtras({required bool includeDev}) {
    if (!includeDev) return List<String>.from(base);
    return [...base, netflixDevOnly];
  }

  /// Ensures stored list has the base items; keeps user additions; optionally
  /// includes/excludes the Netflix dev challenge.
  static List<String> normalize(
    List<String>? stored, {
    required bool includeDev,
  }) {
    final out = <String>[];
    final seen = <String>{};
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty || seen.contains(t.toLowerCase())) return;
      seen.add(t.toLowerCase());
      out.add(t);
    }

    for (final s in stored ?? const <String>[]) {
      if (s.trim() == netflixDevOnly && !includeDev) continue;
      add(s);
    }
    for (final s in base) {
      add(s);
    }
    if (includeDev) add(netflixDevOnly);
    return out;
  }
}

/// Controls what happens when a sprite name is not found in a sheet.
enum MissingSpriteBehavior {
  /// Render a magenta "?" tile — clearly visible during development.
  placeholder,

  /// Render an empty (transparent) rect silently.
  transparent,

  /// Throw an exception with fuzzy-match suggestions.
  error,
}

// lib/utils/exercise_tag_semantics.dart

/// Interprets exercise [tags] into known facets (muscle, equipment, etc.).
///
/// Special meanings live only in this helper — the model stores plain strings.
class ExerciseTagSemantics {
  ExerciseTagSemantics._();

  static const Set<String> muscleGroups = {
    'chest',
    'back',
    'legs',
    'arms',
    'shoulders',
    'core',
    'full_body',
    'other',
  };

  static const Set<String> equipment = {
    'bodyweight',
    'dumbbells',
    'dumbbell',
    'barbell',
    'machine',
    'cables',
    'cable',
    'none',
    'other',
  };

  static const Set<String> categories = {
    'strength',
    'cardio',
    'flexibility',
    'sports',
    'other',
  };

  static const Set<String> difficulties = {
    'beginner',
    'intermediate',
    'advanced',
  };

  /// Built-in special tags used for autocomplete suggestions.
  static Set<String> get catalogTags => {
        ...muscleGroups,
        ...equipment,
        ...categories,
        ...difficulties,
        'gym',
      };

  static String? _firstMatch(List<String> tags, Set<String> known) {
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      if (known.contains(normalized)) return normalized;
    }
    return null;
  }

  static String muscleGroupFromTags(
    List<String> tags, {
    String fallback = 'other',
  }) =>
      _firstMatch(tags, muscleGroups) ?? fallback;

  static String equipmentFromTags(
    List<String> tags, {
    String fallback = 'other',
  }) {
    final match = _firstMatch(tags, equipment);
    if (match == 'dumbbell') return 'dumbbells';
    if (match == 'cable') return 'cables';
    return match ?? fallback;
  }

  static String categoryFromTags(
    List<String> tags, {
    String fallback = 'other',
  }) =>
      _firstMatch(tags, categories) ?? fallback;

  static String difficultyFromTags(
    List<String> tags, {
    String fallback = 'intermediate',
  }) =>
      _firstMatch(tags, difficulties) ?? fallback;

  /// Whether [tag] is one of the interpreted special tags.
  static bool isSpecialTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    return muscleGroups.contains(normalized) ||
        equipment.contains(normalized) ||
        categories.contains(normalized) ||
        difficulties.contains(normalized);
  }

  /// Build a tags list for YAML/storage: keep custom tags, then add specials.
  ///
  /// Matches the simplified YAML shape:
  /// `tags: ["gym", "legs", "barbell", "intermediate"]` (+ category when set).
  static List<String> buildTags({
    required List<String> existing,
    String? category,
    String? muscleGroup,
    String? equipment,
    String? difficulty,
  }) {
    final result = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      result.add(key == trimmed.toLowerCase() ? key : trimmed);
    }

    for (final tag in existing) {
      add(tag);
    }
    add(muscleGroup);
    add(equipment);
    add(category);
    add(difficulty);
    return result;
  }

  /// Normalize a free-form tags list and resolve model fields from it.
  static ({
    List<String> tags,
    String category,
    String muscleGroup,
    String equipment,
    String difficulty,
  }) resolve(List<String> rawTags) {
    final tags = <String>[];
    final seen = <String>{};
    for (final tag in rawTags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      tags.add(key);
    }

    return (
      tags: tags,
      category: categoryFromTags(tags),
      muscleGroup: muscleGroupFromTags(tags),
      equipment: equipmentFromTags(tags),
      difficulty: difficultyFromTags(tags),
    );
  }
}

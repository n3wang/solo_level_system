import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';

/// Displays a workout icon from the `workout_icons_128px` spritesheet.
///
/// The [imageUrl] is the sprite slug (e.g. `"back_squat"`, `"jumping_jacks"`).
/// Sprites are cut at render time from a single GPU texture — no per-file loads.
///
/// Also supports:
///   absolute / `file:` paths from the phone library
///   `assets/...` paths
///
/// Legacy formats handled transparently:
///   `workout_sprite_N` → grid index N (old numbered format)
///   `workout_icon_N`   → grid index N (unnamed high-index sprites)
class WorkoutIconWidget extends StatelessWidget {
  static const String _slicedBasePath = 'assets/icon/workout_icons_sliced';

  /// Sprite slug, asset path, or file path. When null an icon placeholder is shown.
  final String? imageUrl;
  final double? size;
  final Widget? placeholder;
  final Color? backgroundColor;

  const WorkoutIconWidget({
    super.key,
    this.imageUrl,
    this.size,
    this.placeholder,
    this.backgroundColor,
  });

  static bool isFileImagePath(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:')) return true;
    if (url.startsWith('assets/')) return false;
    if (url.startsWith('/') || url.contains('\\')) return true;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url)) return true;
    return false;
  }

  static String? filePathFromImageUrl(String url) {
    if (url.startsWith('file://')) return Uri.parse(url).toFilePath();
    if (url.startsWith('file:')) return url.substring(5);
    return url;
  }

  /// Resolve [imageUrl] into either a named slug or a numeric index.
  ({String? name, int? index})? _resolveSlug() {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    if (isFileImagePath(url) || url.startsWith('assets/')) return null;

    // Legacy: "workout_sprite_N" → index N
    if (url.startsWith('workout_sprite_')) {
      final idx = int.tryParse(url.replaceFirst('workout_sprite_', ''));
      if (idx != null) return (name: null, index: idx);
    }

    // Legacy: "workout_icon_N" → index N (unnamed sprites at the high end)
    if (url.startsWith('workout_icon_')) {
      final idx = int.tryParse(url.replaceFirst('workout_icon_', ''));
      if (idx != null) return (name: null, index: idx);
    }

    // Normal slug: look up by name in the CSV manifest
    return (name: url, index: null);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white;
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return _buildPlaceholder(bgColor);
    }

    if (!kIsWeb && isFileImagePath(url)) {
      final path = filePathFromImageUrl(url)!;
      final file = File(path);
      return _sized(
        bgColor,
        Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(Colors.transparent),
        ),
      );
    }

    if (url.startsWith('assets/')) {
      return _sized(
        bgColor,
        Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(Colors.transparent),
        ),
      );
    }

    final resolved = _resolveSlug();
    if (resolved == null) {
      return _buildPlaceholder(bgColor);
    }

    if (size != null) {
      return RepaintBoundary(
        child: ColoredBox(
          color: bgColor,
          child: _preSlicedOrPlaceholder(resolved, size!),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.biggest.shortestSide;
          return ColoredBox(
            color: bgColor,
            child: _preSlicedOrPlaceholder(resolved, s),
          );
        },
      ),
    );
  }

  Widget _sized(Color bgColor, Widget child) {
    if (size != null) {
      return RepaintBoundary(
        child: ColoredBox(
          color: bgColor,
          child: SizedBox(
            width: size,
            height: size,
            child: child,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.biggest.shortestSide;
          return ColoredBox(
            color: bgColor,
            child: SizedBox(width: s, height: s, child: child),
          );
        },
      ),
    );
  }

  Widget _preSlicedOrPlaceholder(({String? name, int? index}) r, double s) {
    final candidates = _preSlicedCandidates(r);
    final fallback = _buildPlaceholder(Colors.transparent);
    if (candidates.isEmpty) return fallback;

    Widget buildCandidate(int index) {
      if (index >= candidates.length) return fallback;
      return Image.asset(
        candidates[index],
        width: s,
        height: s,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => buildCandidate(index + 1),
      );
    }

    return buildCandidate(0);
  }

  List<String> _preSlicedCandidates(({String? name, int? index}) r) {
    if (r.index != null) {
      return ['$_slicedBasePath/workout_icon_${r.index}.png'];
    }

    final raw = (r.name ?? '').trim().toLowerCase();
    if (raw.isEmpty) return const [];
    final underscore = raw.replaceAll(RegExp(r'\s+'), '_').replaceAll('-', '_');
    final slug = underscore
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final compact = slug.replaceAll('_', '');

    final names = <String>{slug, underscore, compact}.where((n) => n.isNotEmpty);
    return names.map((n) => '$_slicedBasePath/$n.png').toList();
  }

  Widget _buildPlaceholder(Color bgColor) {
    if (placeholder != null) return placeholder!;
    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: bgColor,
          child: Icon(Icons.fitness_center, size: size! * 0.6),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.biggest.shortestSide;
        return SizedBox(
          width: s,
          height: s,
          child: ColoredBox(
            color: bgColor,
            child: Icon(Icons.fitness_center, size: s * 0.6),
          ),
        );
      },
    );
  }
}

/// Displays a workout icon by slug name directly.
class WorkoutIconBySlugWidget extends StatelessWidget {
  final String slug;
  final double? size;
  final Color? backgroundColor;

  const WorkoutIconBySlugWidget({
    super.key,
    required this.slug,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return WorkoutIconWidget(
      imageUrl: slug,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
    );
  }
}

/// Legacy widget — kept for backward compatibility.
/// @deprecated Use [WorkoutIconBySlugWidget] instead.
class WorkoutIconByIndexWidget extends StatelessWidget {
  final int spriteIndex;
  final double? size;
  final Color? backgroundColor;

  const WorkoutIconByIndexWidget({
    super.key,
    required this.spriteIndex,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return WorkoutIconWidget(
      imageUrl: 'workout_icon_$spriteIndex',
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
    );
  }
}

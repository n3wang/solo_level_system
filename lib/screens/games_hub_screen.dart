import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/utils/mini_games.dart';
import 'package:solo_level_system/widgets/common/outlined_entity_tile.dart';

/// Workout → Game tab hub for mini-games.
class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  static const _flagsBox = 'app_init_flags';
  static const _bookmarksKey = 'game_bookmarks';

  final Set<String> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!Hive.isBoxOpen(_flagsBox)) {
      await Hive.openBox(_flagsBox);
    }
    final raw = Hive.box(_flagsBox).get(_bookmarksKey);
    if (!mounted) return;
    setState(() {
      _bookmarked
        ..clear()
        ..addAll(raw is List ? raw.whereType<String>() : const <String>[]);
    });
  }

  Future<void> _toggleBookmark(String gameId) async {
    setState(() {
      if (_bookmarked.contains(gameId)) {
        _bookmarked.remove(gameId);
      } else {
        _bookmarked.add(gameId);
      }
    });
    if (!Hive.isBoxOpen(_flagsBox)) {
      await Hive.openBox(_flagsBox);
    }
    await Hive.box(_flagsBox).put(_bookmarksKey, _bookmarked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final games = MiniGames.catalog;

    // Bookmarked games float to the top (same idea as Sets).
    final ordered = [...games]
      ..sort((a, b) {
        final aBook = _bookmarked.contains(a.id);
        final bBook = _bookmarked.contains(b.id);
        if (aBook == bBook) return 0;
        return aBook ? -1 : 1;
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        const SizedBox(height: 20),
        for (final game in ordered)
          OutlinedEntityTile(
            title: game.title,
            subtitle: game.subtitle,
            footer: 'Never played',
            isBookmarked: _bookmarked.contains(game.id),
            onBookmarkTap: () => _toggleBookmark(game.id),
            onTap: () => MiniGames.open(context, game),
            leading: OutlinedEntityLeading(
              child: Icon(game.icon, color: game.accent, size: 28),
            ),
          ),
      ],
    );
  }
}

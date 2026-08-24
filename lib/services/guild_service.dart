import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class GuildActionResult {
  GuildActionResult({this.data, this.error});

  final Map<String, dynamic>? data;
  final String? error;

  bool get success => error == null;
}

/// Wraps `/api/guilds/*`. Guild membership actions (create/join/leave/
/// password) need connectivity — code uniqueness and auth can't be resolved
/// offline, so those fail fast with a plain error rather than queuing.
///
/// Guild *detail* (ranking/feed) is cached in an untyped Hive box so the
/// guild screens can still render the last-known state offline (same
/// untyped-box precedent as `app_init_flags` in [SoloSyncService]). Forum
/// posts made offline are queued in a small outbox and flushed on retry,
/// mirroring [SoloSyncService]'s `soloSync_outbox` — never throws, silent
/// no-op when offline.
class GuildService {
  GuildService({ApiClient? client}) : _client = client ?? ApiClient();

  static final GuildService instance = GuildService();

  final ApiClient _client;
  static const _cacheBox = 'guild_cache';
  static const _postOutboxBox = 'guildPost_outbox';

  Future<List<Map<String, dynamic>>> fetchMine() async {
    try {
      final response = await _client.get('/api/guilds/mine');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = decodeJsonList(response.body);
      return decoded;
    } catch (_) {
      return const [];
    }
  }

  Future<GuildActionResult> create({required String name, String? password}) async {
    try {
      final response = await _client.post('/api/guilds', {
        'name': name,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      return _resultFrom(response);
    } catch (_) {
      return GuildActionResult(error: 'No connection to server.');
    }
  }

  Future<GuildActionResult> join({required String code, String? password}) async {
    try {
      final response = await _client.post('/api/guilds/join', {
        'code': code,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      return _resultFrom(response);
    } catch (_) {
      return GuildActionResult(error: 'No connection to server.');
    }
  }

  /// Fetches guild detail (ranking + feed + my sharing config), caching it
  /// locally. On failure, returns the last cached copy (if any) so the
  /// screen still has something to show offline.
  Future<Map<String, dynamic>?> fetchDetail(String guildId) async {
    try {
      final response = await _client.get('/api/guilds/$guildId');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedDetail(guildId);
      }
      final data = decodeJsonMap(response.body);
      final box = await _cache();
      await box.put(guildId, data);
      return data;
    } catch (_) {
      return _cachedDetail(guildId);
    }
  }

  Future<Map<String, dynamic>?> _cachedDetail(String guildId) async {
    final box = await _cache();
    final cached = box.get(guildId);
    if (cached is Map) {
      return cached.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<bool> updateSharing(
    String guildId, {
    required bool shareAllProjects,
    required List<String> sharedProjectNames,
    required bool shareFocusSessions,
    required bool shareWorkoutSessions,
  }) async {
    try {
      final response = await _client.put('/api/guilds/$guildId/sharing', {
        'shareAllProjects': shareAllProjects,
        'sharedProjectNames': sharedProjectNames,
        'shareFocusSessions': shareFocusSessions,
        'shareWorkoutSessions': shareWorkoutSessions,
      });
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Posts to a guild's feed. Queued locally (never throws) if offline —
  /// call [retryPostOutbox] later (e.g. on reconnect) to flush it.
  Future<bool> post(String guildId, String text) async {
    try {
      final response = await _client.post('/api/guilds/$guildId/posts', {
        'text': text,
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    await _queuePost(guildId, text);
    return false;
  }

  Future<void> retryPostOutbox() async {
    final box = await _postOutbox();
    final keys = box.keys.toList();
    for (final key in keys) {
      final entry = box.get(key);
      if (entry is! Map) continue;
      final guildId = entry['guildId']?.toString();
      final text = entry['text']?.toString();
      if (guildId == null || text == null) {
        await box.delete(key);
        continue;
      }
      try {
        final response = await _client.post('/api/guilds/$guildId/posts', {
          'text': text,
        });
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await box.delete(key);
        }
      } catch (_) {
        // Still offline — leave queued, try again next call.
      }
    }
  }

  Future<void> _queuePost(String guildId, String text) async {
    final box = await _postOutbox();
    await box.add({'guildId': guildId, 'text': text});
  }

  Future<bool> setPassword(String guildId, String? password) async {
    try {
      final response = await _client.put('/api/guilds/$guildId/password', {
        if (password != null) 'password': password,
      });
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leave(String guildId) async {
    try {
      final response = await _client.delete('/api/guilds/$guildId/leave');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final box = await _cache();
        await box.delete(guildId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  GuildActionResult _resultFrom(http.Response response) {
    final body = decodeJsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return GuildActionResult(
        error: body['error']?.toString() ?? 'Something went wrong.',
      );
    }
    return GuildActionResult(data: body);
  }

  Future<Box> _cache() async {
    if (!Hive.isBoxOpen(_cacheBox)) {
      return Hive.openBox(_cacheBox);
    }
    return Hive.box(_cacheBox);
  }

  Future<Box> _postOutbox() async {
    if (!Hive.isBoxOpen(_postOutboxBox)) {
      return Hive.openBox(_postOutboxBox);
    }
    return Hive.box(_postOutboxBox);
  }
}

List<Map<String, dynamic>> decodeJsonList(String body) {
  if (body.isEmpty) return const [];
  try {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
  } catch (_) {}
  return const [];
}

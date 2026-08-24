import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TokenStore {
  static const _accessKey = 'solo_access_token';
  static const _refreshKey = 'solo_refresh_token';
  static const _emailKey = 'solo_email';
  static const _handleKey = 'solo_handle';
  static const _rememberKey = 'solo_remember_me';
  static const _hiveBox = 'account_session';

  static const _secure = FlutterSecureStorage();

  static String? _memAccess;
  static String? _memRefresh;
  static String? _memEmail;
  static bool skipDevAutoLoginThisSession = false;

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String email,
  }) async {
    _memAccess = accessToken;
    _memRefresh = refreshToken;
    _memEmail = email;
    skipDevAutoLoginThisSession = false;
    final remember = await rememberMe();
    if (!remember) {
      await _deletePersistedTokens();
      return;
    }
    await _writePersisted(_accessKey, accessToken);
    await _writePersisted(_refreshKey, refreshToken);
    await _writePersisted(_emailKey, email);
  }

  static Future<String?> accessToken() async {
    if (_memAccess != null && _memAccess!.isNotEmpty) return _memAccess;
    if (!await rememberMe()) return null;
    return _read(_accessKey);
  }

  static Future<String?> refreshToken() async {
    if (_memRefresh != null && _memRefresh!.isNotEmpty) return _memRefresh;
    if (!await rememberMe()) return null;
    return _read(_refreshKey);
  }

  static Future<String?> email() async {
    if (_memEmail != null && _memEmail!.isNotEmpty) return _memEmail;
    return _read(_emailKey);
  }

  static Future<String?> cachedHandle() async {
    return _read(_handleKey);
  }

  static Future<void> setCachedHandle(String handle) async {
    await _writePersisted(_handleKey, handle);
  }

  /// Default on: missing key means remember this device.
  static Future<bool> rememberMe() async {
    final raw = await _hiveRead(_rememberKey);
    if (raw == null) return true;
    return raw == 'true' || raw == '1';
  }

  static Future<void> setRememberMe(bool value) async {
    final box = await _box();
    await box.put(_rememberKey, value ? 'true' : 'false');
    if (!value) {
      await _deletePersistedTokens();
    } else if (_memAccess != null && _memRefresh != null) {
      await save(
        accessToken: _memAccess!,
        refreshToken: _memRefresh!,
        email: _memEmail ?? '',
      );
    }
  }

  static Future<String?> _read(String key) async {
    if (!kIsWeb) {
      try {
        final value = await _secure.read(key: key);
        if (value != null && value.isNotEmpty) return value;
      } catch (_) {}
    }
    return _hiveRead(key);
  }

  static Future<void> _writePersisted(String key, String value) async {
    if (!kIsWeb) {
      try {
        await _secure.write(key: key, value: value);
        return;
      } catch (_) {}
    }
    final box = await _box();
    await box.put(key, value);
  }

  static Future<void> _deletePersistedTokens() async {
    if (!kIsWeb) {
      try {
        await _secure.delete(key: _accessKey);
        await _secure.delete(key: _refreshKey);
      } catch (_) {}
    }
    if (Hive.isBoxOpen(_hiveBox)) {
      final box = Hive.box(_hiveBox);
      await box.delete(_accessKey);
      await box.delete(_refreshKey);
    }
  }

  static Future<void> clearSession({bool keepCachedEmail = false}) async {
    _memAccess = null;
    _memRefresh = null;
    if (!keepCachedEmail) {
      _memEmail = null;
    }
    await _deletePersistedTokens();
    if (!keepCachedEmail) {
      if (!kIsWeb) {
        try {
          await _secure.delete(key: _emailKey);
          await _secure.delete(key: _handleKey);
        } catch (_) {}
      }
      if (Hive.isBoxOpen(_hiveBox)) {
        await Hive.box(_hiveBox).delete(_emailKey);
        await Hive.box(_hiveBox).delete(_handleKey);
      }
    }
  }

  static Future<void> clear() async {
    await clearSession(keepCachedEmail: false);
    if (Hive.isBoxOpen(_hiveBox)) {
      await Hive.box(_hiveBox).clear();
    }
  }

  static Future<Box> _box() async {
    if (!Hive.isBoxOpen(_hiveBox)) {
      return Hive.openBox(_hiveBox);
    }
    return Hive.box(_hiveBox);
  }

  static Future<String?> _hiveRead(String key) async {
    try {
      final box = await _box();
      final value = box.get(key);
      return value?.toString();
    } catch (_) {
      return null;
    }
  }
}

String jsonBody(Map<String, dynamic> map) => jsonEncode(map);

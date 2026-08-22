import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TokenStore {
  static const _accessKey = 'solo_access_token';
  static const _refreshKey = 'solo_refresh_token';
  static const _emailKey = 'solo_email';
  static const _hiveBox = 'account_session';

  static const _secure = FlutterSecureStorage();

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String email,
  }) async {
    if (!kIsWeb) {
      try {
        await _secure.write(key: _accessKey, value: accessToken);
        await _secure.write(key: _refreshKey, value: refreshToken);
        await _secure.write(key: _emailKey, value: email);
        return;
      } catch (_) {}
    }
    final box = await _box();
    await box.put(_accessKey, accessToken);
    await box.put(_refreshKey, refreshToken);
    await box.put(_emailKey, email);
  }

  static Future<String?> accessToken() async => _read(_accessKey);

  static Future<String?> refreshToken() async => _read(_refreshKey);

  static Future<String?> email() async => _read(_emailKey);

  static Future<String?> _read(String key) async {
    if (!kIsWeb) {
      try {
        final value = await _secure.read(key: key);
        if (value != null && value.isNotEmpty) return value;
      } catch (_) {}
    }
    return _hiveRead(key);
  }

  static Future<void> clear() async {
    if (!kIsWeb) {
      try {
        await _secure.delete(key: _accessKey);
        await _secure.delete(key: _refreshKey);
        await _secure.delete(key: _emailKey);
      } catch (_) {}
    }
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
    if (!Hive.isBoxOpen(_hiveBox) && !Hive.isAdapterRegistered(0)) {
      // box may not exist in tests
    }
    try {
      final box = await _box();
      final value = box.get(key);
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }
}

String jsonBody(Map<String, dynamic> map) => jsonEncode(map);

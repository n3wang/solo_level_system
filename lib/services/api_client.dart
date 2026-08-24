import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.offline = false});
  final String message;
  final int? statusCode;
  final bool offline;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<http.Response> get(String path) => _send('GET', path);

  Future<http.Response> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  Future<http.Response> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body);

  Future<http.Response> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body);

  Future<http.Response> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool retried = false,
  ]) async {
    final uri = Uri.parse('${AppEnvironment.apiBaseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await TokenStore.accessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final encoded = body == null ? null : jsonEncode(body);
    try {
      late final Future<http.Response> request;
      switch (method) {
        case 'GET':
          request = _http.get(uri, headers: headers);
          break;
        case 'PUT':
          request = _http.put(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          request = _http.delete(uri, headers: headers, body: encoded);
          break;
        default:
          request = _http.post(uri, headers: headers, body: encoded);
      }
      final response = await request.timeout(AppEnvironment.apiTimeout);

      if (response.statusCode == 401 &&
          !retried &&
          !path.startsWith('/api/auth/')) {
        final refreshed = await _refresh();
        if (refreshed) {
          return _send(method, path, body, true);
        }
      }
      return response;
    } on TimeoutException {
      throw ApiException('Server timed out', offline: true);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No connection to server', offline: true);
    }
  }

  Future<bool> _refresh() async {
    final refresh = await TokenStore.refreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final uri = Uri.parse('${AppEnvironment.apiBaseUrl}/api/auth/refresh');
      final response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(AppEnvironment.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      await TokenStore.save(
        accessToken: data['accessToken']?.toString() ?? '',
        refreshToken: data['refreshToken']?.toString() ?? refresh,
        email: data['email']?.toString() ?? (await TokenStore.email() ?? ''),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

Map<String, dynamic> decodeJsonMap(String body) {
  if (body.isEmpty) return {};
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {}
  return {};
}

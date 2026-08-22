import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_environment.dart';
import 'api_client.dart';
import 'token_store.dart';

class AccountSession {
  AccountSession._();
  static final AccountSession instance = AccountSession._();

  final ValueNotifier<bool> loggedIn = ValueNotifier(false);
  final ValueNotifier<String?> email = ValueNotifier(null);

  Future<void> restore() async {
    final token = await TokenStore.accessToken();
    email.value = await TokenStore.email();
    loggedIn.value = token != null && token.isNotEmpty;
  }
}

class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> register(String email, String password) async {
    await _authPost('/api/auth/register', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<void> login(String email, String password) async {
    await _authPost('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<void> loginWithGoogle() async {
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppEnvironment.googleServerClientId.isEmpty
            ? null
            : AppEnvironment.googleServerClientId,
      );
      final account = await google.signIn().timeout(const Duration(seconds: 20));
      if (account == null) {
        throw ApiException('Google sign-in cancelled');
      }
      final auth = await account.authentication.timeout(AppEnvironment.apiTimeout);
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException('Google did not return an ID token');
      }
      await _authPost('/api/auth/google', {'idToken': idToken});
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Google sign-in timed out', offline: true);
    } catch (_) {
      throw ApiException('Google sign-in failed', offline: true);
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStore.refreshToken();
    try {
      if (refresh != null) {
        await _client.post('/api/auth/logout', {'refreshToken': refresh});
      }
    } catch (_) {
      // Local logout still proceeds if the backend is down.
    }
    await TokenStore.clear();
    AccountSession.instance.loggedIn.value = false;
    AccountSession.instance.email.value = null;
  }

  Future<void> _authPost(String path, Map<String, dynamic> body) async {
    final response = await _client.post(path, body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = decodeJsonMap(response.body);
      final error = map['error']?.toString() ??
          (map['errors'] is List
              ? (map['errors'] as List).join(', ')
              : 'Auth failed');
      throw ApiException(
        error.isEmpty ? 'Auth failed' : error,
        statusCode: response.statusCode,
      );
    }
    final data = decodeJsonMap(response.body);
    await TokenStore.save(
      accessToken: data['accessToken']?.toString() ?? '',
      refreshToken: data['refreshToken']?.toString() ?? '',
      email: data['email']?.toString() ?? body['email']?.toString() ?? '',
    );
    AccountSession.instance.loggedIn.value = true;
    AccountSession.instance.email.value = await TokenStore.email();
  }
}

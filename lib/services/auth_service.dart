import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_environment.dart';
import 'api_client.dart';
import 'profile_service.dart';
import 'solo_sync_service.dart';
import 'token_store.dart';

class AccountSession {
  AccountSession._();
  static final AccountSession instance = AccountSession._();

  final ValueNotifier<bool> loggedIn = ValueNotifier(false);
  final ValueNotifier<String?> email = ValueNotifier(null);
  final ValueNotifier<String?> handle = ValueNotifier(null);
  final ValueNotifier<bool> rememberMe = ValueNotifier(true);

  Future<void> restore() async {
    rememberMe.value = await TokenStore.rememberMe();
    email.value = await TokenStore.email();
    handle.value = await TokenStore.cachedHandle();
    final token = await TokenStore.accessToken();
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
      final auth = await account.authentication.timeout(
        AppEnvironment.apiTimeout,
      );
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
    } catch (_) {}
    final remember = await TokenStore.rememberMe();
    await TokenStore.clearSession(keepCachedEmail: remember);
    TokenStore.skipDevAutoLoginThisSession = true;
    AccountSession.instance.loggedIn.value = false;
    AccountSession.instance.email.value = remember
        ? await TokenStore.email()
        : null;
    AccountSession.instance.handle.value = remember
        ? await TokenStore.cachedHandle()
        : null;
  }

  /// Silent restore + developer auto-login. Never throws.
  Future<void> ensureStartupSession() async {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return;
    try {
      await AccountSession.instance.restore();
      if (AccountSession.instance.loggedIn.value) {
        unawaited(SoloSyncService.instance.retryOutbox());
        unawaited(_refreshCachedProfile());
        return;
      }
      if (TokenStore.skipDevAutoLoginThisSession) return;
      if (!AppEnvironment.isTest) return;
      if (!await TokenStore.rememberMe()) return;
      await _loginOrRegisterDev();
      unawaited(SoloSyncService.instance.onLoggedIn());
    } catch (_) {}
  }

  Future<void> _loginOrRegisterDev() async {
    try {
      await login(
        AppEnvironment.devAccountEmail,
        AppEnvironment.devAccountPassword,
      );
    } on ApiException catch (e) {
      if (e.statusCode != 401 && e.statusCode != 400) rethrow;
      try {
        await register(
          AppEnvironment.devAccountEmail,
          AppEnvironment.devAccountPassword,
        );
      } catch (_) {
        await login(
          AppEnvironment.devAccountEmail,
          AppEnvironment.devAccountPassword,
        );
      }
    }
  }

  Future<void> _refreshCachedProfile() async {
    try {
      final handle = await ProfileService.instance.fetchHandle();
      if (handle != null && handle.isNotEmpty) {
        await TokenStore.setCachedHandle(handle);
        AccountSession.instance.handle.value = handle;
      }
    } catch (_) {}
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
    TokenStore.skipDevAutoLoginThisSession = false;
    AccountSession.instance.loggedIn.value = true;
    AccountSession.instance.email.value = await TokenStore.email();
    unawaited(_refreshCachedProfile());
  }
}

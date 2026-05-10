import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({ApiService? apiService}) : _api = apiService ?? ApiService() {
    _api.registerAuthStateHandlers(
      onAuthTokensUpdated: _syncRefreshedTokens,
      onUnauthorized: _handleUnauthorized,
    );
    _restoreSession();
  }

  static const _userStorageKey = 'auth.user';
  static const _accessTokenStorageKey = 'auth.access_token';
  static const _refreshTokenStorageKey = 'auth.refresh_token';

  final ApiService _api;

  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isSubmitting = false;
  bool _isRestoringSession = true;

  User? get currentUser => _currentUser;
  bool get isAuthenticated =>
      _currentUser != null && _accessToken != null && _accessToken!.isNotEmpty;
  bool get isSubmitting => _isSubmitting;
  bool get isRestoringSession => _isRestoringSession;

  Future<void> updateCurrentUser(User user) async {
    _currentUser = user;
    _api.setUserId(user.id.toString());

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userStorageKey, jsonEncode(user.toJson()));

    notifyListeners();
  }

  Future<User> loginWithNickname({
    required String nickname,
    required String password,
  }) async {
    return _runSubmission(() async {
      try {
        final result = await _api.loginWithNickname(
          nickname: nickname.trim(),
          password: password.trim(),
        );

        if (result.accessToken == null || result.accessToken!.isEmpty) {
          throw const AuthException(
            'Sign-in succeeded, but the server did not return an access token.',
          );
        }

        await _applySession(
          user: result.user,
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken,
        );
      } on DioException catch (error) {
        throw AuthException(_extractApiError(error));
      } on FormatException catch (error) {
        throw AuthException(error.message);
      }

      return _currentUser!;
    });
  }

  Future<User> register({
    required String nickname,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    return _runSubmission(() async {
      try {
        final result = await _api.register(
          nickname: nickname.trim(),
          phone: phoneNumber.trim(),
          password: password.trim(),
          confirmPassword: confirmPassword.trim(),
        );

        if (result.accessToken != null && result.accessToken!.isNotEmpty) {
          await _applySession(
            user: result.user,
            accessToken: result.accessToken!,
            refreshToken: result.refreshToken,
          );
          return _currentUser!;
        }

        return await _loginAfterRegister(
          nickname: nickname.trim(),
          password: password.trim(),
        );
      } on DioException catch (error) {
        throw AuthException(_extractApiError(error));
      } on FormatException {
        return _loginAfterRegister(
          nickname: nickname.trim(),
          password: password.trim(),
        );
      }
    });
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;

    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _api.logout(refreshToken: refreshToken);
      }
    } finally {
      await _clearSession();
    }
  }

  Future<T> _runSubmission<T>(Future<T> Function() action) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await action();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<User> _loginAfterRegister({
    required String nickname,
    required String password,
  }) async {
    final loginResult = await _api.loginWithNickname(
      nickname: nickname,
      password: password,
    );

    if (loginResult.accessToken == null || loginResult.accessToken!.isEmpty) {
      throw const AuthException(
        'Registration succeeded, but automatic sign-in is missing an access token.',
      );
    }

    await _applySession(
      user: loginResult.user,
      accessToken: loginResult.accessToken!,
      refreshToken: loginResult.refreshToken,
    );

    return _currentUser!;
  }

  Future<void> _restoreSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encodedUser = preferences.getString(_userStorageKey);
      final accessToken = preferences.getString(_accessTokenStorageKey);
      final refreshToken = preferences.getString(_refreshTokenStorageKey);

      if (encodedUser == null || accessToken == null || accessToken.isEmpty) {
        await _clearSession(notify: false);
        return;
      }

      final decodedUser = jsonDecode(encodedUser);
      if (decodedUser is! Map<String, dynamic>) {
        await _clearSession(notify: false);
        return;
      }

      _currentUser = User.fromJson(decodedUser);
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _api.setAccessToken(_accessToken);
      _api.setRefreshToken(_refreshToken);
      if (_currentUser != null) {
        _api.setUserId(_currentUser!.id.toString());
      }
    } catch (error) {
      debugPrint('Restore auth session failed: $error');
      await _clearSession(notify: false);
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> _applySession({
    required User user,
    required String accessToken,
    required String? refreshToken,
  }) async {
    _currentUser = user;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _api.setAccessToken(accessToken);
    _api.setRefreshToken(refreshToken);
    _api.setUserId(user.id.toString());

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userStorageKey, jsonEncode(user.toJson()));
    await preferences.setString(_accessTokenStorageKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await preferences.setString(_refreshTokenStorageKey, refreshToken);
    } else {
      await preferences.remove(_refreshTokenStorageKey);
    }

    notifyListeners();
  }

  Future<void> _clearSession({bool notify = true}) async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _api.setAccessToken(null);
    _api.setRefreshToken(null);
    _api.setUserId(null);

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userStorageKey);
    await preferences.remove(_accessTokenStorageKey);
    await preferences.remove(_refreshTokenStorageKey);

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _syncRefreshedTokens(
    String accessToken,
    String? refreshToken,
  ) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _api.setAccessToken(accessToken);
    _api.setRefreshToken(refreshToken);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accessTokenStorageKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await preferences.setString(_refreshTokenStorageKey, refreshToken);
    } else {
      await preferences.remove(_refreshTokenStorageKey);
    }

    notifyListeners();
  }

  Future<void> _handleUnauthorized() async {
    if (_currentUser == null &&
        (_accessToken == null || _accessToken!.isEmpty) &&
        (_refreshToken == null || _refreshToken!.isEmpty)) {
      return;
    }

    await _clearSession();
  }

  String _extractApiError(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final map = data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final directMessage = _firstMessage([
        map['message'],
        map['error'],
        map['detail'],
      ]);

      if (directMessage != null) {
        return directMessage;
      }

      final errors = map['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          final nestedMessage = _firstMessage([value]);
          if (nestedMessage != null) {
            return nestedMessage;
          }
        }
      }
    }

    return 'Request failed. Please try again later.';
  }

  String? _firstMessage(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.isNotEmpty) {
        return value;
      }

      if (value is List && value.isNotEmpty) {
        final firstItem = value.first;
        if (firstItem is String && firstItem.isNotEmpty) {
          return firstItem;
        }
      }
    }

    return null;
  }
}

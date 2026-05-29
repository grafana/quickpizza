import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for TokenStorage with dependency injection
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Represents a stored authentication session.
class StoredSession extends Equatable {
  const StoredSession({this.token, this.username});

  final String? token;
  final String? username;

  bool get isValid => token != null && username != null;

  @override
  List<Object?> get props => [token, username];
}

const _tokenKey = 'auth_token';
const _usernameKey = 'auth_username';

/// Handles persistent storage of authentication session data.
///
/// Auth tokens are stored in [FlutterSecureStorage]; usernames remain in
/// SharedPreferences for quick reads.
class TokenStorage {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _sessionController = StreamController<StoredSession>.broadcast();

  Stream<StoredSession> get sessionChanges =>
      _sessionController.stream.distinct();

  Future<void> saveSession({
    required String token,
    required String username,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.remove(_tokenKey);
    _sessionController.add(StoredSession(token: token, username: username));
  }

  Future<StoredSession> loadSession() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final session = StoredSession(token: token, username: username);
    _sessionController.add(session);
    return session;
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
    _sessionController.add(const StoredSession());
  }
}

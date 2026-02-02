import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Handles persistent storage of authentication session data.
///
/// Uses SharedPreferences to store the auth token and username
/// so the user remains logged in across app restarts.
///
/// Exposes a [sessionChanges] stream that emits whenever the session is
/// saved or cleared, allowing subscribers (like ApiClient) to react to changes.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';

  final _sessionController = StreamController<StoredSession>.broadcast();

  /// Stream that emits whenever the session changes.
  /// Only emits if the value is different from the last emission (distinct).
  Stream<StoredSession> get sessionChanges =>
      _sessionController.stream.distinct();

  /// Saves the authentication session to persistent storage.
  Future<void> saveSession({
    required String token,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, username);
    _sessionController.add(StoredSession(token: token, username: username));
  }

  /// Loads the saved authentication session from persistent storage.
  ///
  /// Returns a [StoredSession] and emits on the stream if the value changed.
  Future<StoredSession> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    final session = StoredSession(token: token, username: username);
    _sessionController.add(session);
    return session;
  }

  /// Clears the saved authentication session from persistent storage.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    _sessionController.add(const StoredSession());
  }
}

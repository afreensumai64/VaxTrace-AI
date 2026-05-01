// VaxTrace AI — JWT Auth Service (zero-cost, no external service)
// Drop-in replacement for firebase_auth_service.dart.
// Talks to the FastAPI /auth/* endpoints and stores token in SharedPreferences.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _kTokenKey = 'jwt_token';
const String _kUserKey = 'jwt_user';

class JwtUser {
  final String userId;
  final String email;
  final String? displayName;

  const JwtUser({
    required this.userId,
    required this.email,
    this.displayName,
  });

  factory JwtUser.fromJson(Map<String, dynamic> json) => JwtUser(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'display_name': displayName,
      };

  String get displayLabel => displayName ?? email;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class JwtAuthService {
  final String baseUrl;

  JwtAuthService({required this.baseUrl});

  // ─────────────────────────────────────────────
  // Token persistence
  // ─────────────────────────────────────────────

  Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Future<void> _saveSession(String token, JwtUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }

  // ─────────────────────────────────────────────
  // Current user (synchronous, from cache)
  // ─────────────────────────────────────────────

  JwtUser? _cachedUser;

  Future<JwtUser?> get currentUser async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null) return null;
    try {
      _cachedUser = JwtUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedInSync => _cachedUser != null;

  // ─────────────────────────────────────────────
  // Auth state stream (mimics Firebase authStateChanges)
  // Emits true/false as login state changes
  // ─────────────────────────────────────────────

  Stream<JwtUser?> get authStateChanges => _authController.stream;
  final _authController =
      _BroadcastController<JwtUser?>();

  Future<void> init() async {
    final user = await currentUser;
    _authController.emit(user);
  }

  // ─────────────────────────────────────────────
  // Sign in
  // ─────────────────────────────────────────────

  Future<JwtUser> signInWithEmail(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AuthException(body['detail'] as String? ?? 'Login failed');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final user = JwtUser.fromJson(data);

    _cachedUser = user;
    await _saveSession(token, user);
    _authController.emit(user);
    return user;
  }

  // ─────────────────────────────────────────────
  // Sign up
  // ─────────────────────────────────────────────

  Future<JwtUser> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
      }),
    );

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AuthException(body['detail'] as String? ?? 'Registration failed');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final user = JwtUser.fromJson(data);

    _cachedUser = user;
    await _saveSession(token, user);
    _authController.emit(user);
    return user;
  }

  // ─────────────────────────────────────────────
  // Sign out
  // ─────────────────────────────────────────────

  Future<void> signOut() async {
    _cachedUser = null;
    await _clearSession();
    _authController.emit(null);
  }

  String get displayName => _cachedUser?.displayLabel ?? 'Health Worker';
}

// ─────────────────────────────────────────────
// Minimal broadcast stream controller
// (avoids dart:async StreamController boilerplate)
// ─────────────────────────────────────────────

class _BroadcastController<T> {
  final List<void Function(T)> _listeners = [];

  Stream<T> get stream => Stream.multi((controller) {
        _listeners.add(controller.add);
        controller.onCancel = () => _listeners.remove(controller.add);
      });

  void emit(T value) {
    for (final l in List.of(_listeners)) {
      l(value);
    }
  }
}

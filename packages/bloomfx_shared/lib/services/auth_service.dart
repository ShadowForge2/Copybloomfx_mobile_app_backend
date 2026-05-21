import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _adminKey = 'auth_is_admin';
  static const _credMapKey = 'auth_credentials_map';
  static const _lastActiveUserKey = 'auth_last_active_user';
  static const _lastActivityKey = 'auth_last_activity';

  static Future<void> storeAuthData({
    required String token,
    required User user,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_lastActiveUserKey, user.username);
    if (isAdmin) {
      await prefs.setBool(_adminKey, true);
    }
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  static Future<void> storeAdminToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_adminKey, true);
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  static Future<void> storeCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_credMapKey);
    final map = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : <String, dynamic>{};
    final encoded = base64Encode(utf8.encode(password));
    map[username] = encoded;
    await prefs.setString(_credMapKey, jsonEncode(map));
    await prefs.setString(_lastActiveUserKey, username);
  }

  static Future<Map<String, String>> getAllStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_credMapKey);
    if (raw == null) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      return map.map((k, v) => MapEntry(k, utf8.decode(base64Decode(v.toString()))));
    } catch (_) {
      return {};
    }
  }

  static Future<void> removeStoredCredentials(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_credMapKey);
    if (raw == null) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      map.remove(username);
      if (map.isEmpty) {
        await prefs.remove(_credMapKey);
      } else {
        await prefs.setString(_credMapKey, jsonEncode(map));
      }
    } catch (_) {}
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credMapKey);
    await prefs.remove(_lastActiveUserKey);
  }

  static Future<String?> getLastActiveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastActiveUserKey);
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_adminKey);
    await prefs.remove(_lastActivityKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminKey) ?? false;
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastActivityKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}

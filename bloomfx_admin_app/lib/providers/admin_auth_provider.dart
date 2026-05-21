import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminAuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  AdminAuthProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  User? _adminUser;
  bool _isAuthenticated = false;
  bool _isOffline = false;
  String? _errorMessage;

  User? get adminUser => _adminUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password,
      {bool remember = true}) async {
    try {
      _errorMessage = null;
      _isOffline = false;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[AdminAuth] login → POST /api/auth/login (user: $username)');
      }

      final res = await _apiService.login(username, password);

      if (kDebugMode) {
        debugPrint(
          '[AdminAuth] login response: success=${res.success} message=${res.message}',
        );
      }

      if (res.success && res.data != null) {
        final token = res.data!['token']?.toString() ?? '';
        final userJson = res.data!['user'] as Map<String, dynamic>?;
        if (userJson != null) {
          final user = User.fromJson(userJson);
          if (user.role != UserRole.admin) {
            _errorMessage = 'Not an admin account';
            notifyListeners();
            return false;
          }
          if (token.isEmpty) {
            _errorMessage = 'Login succeeded but no token was returned';
            notifyListeners();
            return false;
          }
          _adminUser = user;
          _isAuthenticated = true;
          await AuthService.storeAuthData(token: token, user: user, isAdmin: true);
          if (remember) {
            await AuthService.storeCredentials(username: username, password: password);
          }
          notifyListeners();
          return true;
        }
        _errorMessage = 'Invalid login response from server';
        notifyListeners();
        return false;
      }

      _errorMessage = res.message.isNotEmpty ? res.message : 'Login failed';
      notifyListeners();
      return false;
    } on TimeoutException {
      _errorMessage =
          'Server timed out. If hosted on Render, it may be cold-starting (up to 30-60s). Please try again.';
      notifyListeners();
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AdminAuth] login error: $e');
        debugPrint('$st');
      }
      _errorMessage = 'Login failed. Please check your credentials and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.clearAuthData();
    await AuthService.clearCredentials();
    _adminUser = null;
    _isAuthenticated = false;
    _isOffline = false;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    try {
      final isAuth = await AuthService.isAuthenticated();
      final isAdmin = await AuthService.isAdmin();
      if (isAuth && isAdmin) {
        final user = await AuthService.getCurrentUser();
        if (user != null && user.role == UserRole.admin) {
          _adminUser = user;
          _isAuthenticated = true;
          notifyListeners();
          return;
        }
      }

      final creds = await AuthService.getAllStoredCredentials();
      if (creds.isNotEmpty) {
        final lastUser = await AuthService.getLastActiveUsername();
        if (lastUser != null && creds.containsKey(lastUser)) {
          final ok = await login(lastUser, creds[lastUser]!, remember: true);
          if (ok) return;
        }
      }

      await logout();
    } catch (_) {
      await logout();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

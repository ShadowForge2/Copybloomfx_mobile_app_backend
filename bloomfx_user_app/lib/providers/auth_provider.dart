import 'package:flutter/foundation.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SupabaseService _supabase = SupabaseService();
  User? _user;
  bool _isAuthenticated = false;
  String? _errorMessage;

  AuthProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password, {bool remember = true}) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final res = await _apiService.login(email, password);
      if (res.success && res.data != null) {
        final token = res.data!['token']?.toString() ?? '';
        final userJson = res.data!['user'] as Map<String, dynamic>?;
        if (userJson != null) {
          _user = User.fromJson(userJson);
          _isAuthenticated = true;
          await AuthService.storeAuthData(
            token: token,
            user: _user!,
            isAdmin: _user!.role == UserRole.admin,
          );
          if (remember) {
            await AuthService.storeCredentials(username: email, password: password);
          }
          notifyListeners();
          return true;
        }
      }
      _errorMessage = res.message.isNotEmpty ? res.message : 'Login failed';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed. Please check your credentials and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String username,
    String password, {
    String? email,
  }) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final res = await _apiService.register(username, password, email: email);
      if (res.success && res.data != null) {
        final token = res.data!['token']?.toString() ?? '';
        final userJson = res.data!['user'] as Map<String, dynamic>?;
        if (userJson != null) {
          _user = User.fromJson(userJson);
          _isAuthenticated = true;
          await AuthService.storeAuthData(
            token: token,
            user: _user!,
            isAdmin: _user!.role == UserRole.admin,
          );
          await AuthService.storeCredentials(username: username, password: password);
          notifyListeners();
          return true;
        }
      }
      _errorMessage = res.message.isNotEmpty ? res.message : 'Registration failed';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithDetails(
    String firstName,
    String lastName,
    String email,
    String password, {
    String? username,
    String? referralCode,
  }) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final user = username ?? '${firstName.toLowerCase()}_${lastName.toLowerCase()}';
      final trimmedReferral = referralCode?.trim();
      final res = await _apiService.register(
        user,
        password,
        email: email,
        firstName: firstName,
        lastName: lastName,
        referrerCode: (trimmedReferral != null && trimmedReferral.isNotEmpty) ? trimmedReferral : null,
      );
      if (res.success && res.data != null) {
        final token = res.data!['token']?.toString() ?? '';
        final userJson = res.data!['user'] as Map<String, dynamic>?;
        if (userJson != null) {
          _user = User.fromJson(userJson);
          _isAuthenticated = true;
          await AuthService.storeAuthData(
            token: token,
            user: _user!,
            isAdmin: _user!.role == UserRole.admin,
          );
          await AuthService.storeCredentials(username: user, password: password);
          notifyListeners();
          return true;
        }
      }
      _errorMessage = res.message.isNotEmpty ? res.message : 'Registration failed';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.signOut();
    await AuthService.clearAuthData();
    await AuthService.clearCredentials();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    try {
      final session = _supabase.currentSession;
      if (session != null) {
        final userData = await _supabase.fetchUserByAuthId(session.user?.id ?? '');
        if (userData != null) {
          _user = _supabase.mapToUser(userData);
          _isAuthenticated = true;
          notifyListeners();
          return;
        }
      }

      final isAuth = await AuthService.isAuthenticated();
      if (isAuth) {
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          _user = user;
          _isAuthenticated = true;
          notifyListeners();
          return;
        }
      }

      final creds = await AuthService.getAllStoredCredentials();
      if (creds.isNotEmpty) {
        final lastUser = await AuthService.getLastActiveUsername();
        final entries = creds.entries.toList();
        if (lastUser != null && creds.containsKey(lastUser)) {
          final ok = await login(lastUser, creds[lastUser]!);
          if (ok) return;
        }
        int attempts = 0;
        for (final entry in entries) {
          if (entry.key == lastUser) continue;
          if (attempts >= 3) break;
          attempts++;
          await Future.delayed(const Duration(milliseconds: 300));
          final ok = await login(entry.key, entry.value);
          if (ok) return;
        }
      }

      await logout();
    } catch (e) {
      await logout();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

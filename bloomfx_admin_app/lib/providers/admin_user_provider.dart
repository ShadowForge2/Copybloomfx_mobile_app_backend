import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminUserProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _filter = 'all';

  AdminUserProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get filter => _filter;

  bool get _useLocalOnly =>
      _apiService.baseUrl.contains('your-backend-api.com') ||
      _apiService.baseUrl.contains('10.0.2.2') ||
      _apiService.baseUrl.contains('127.0.0.1') ||
      _apiService.baseUrl.contains('localhost');

  void setFilter(String f) {
    _filter = f;
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // --- API path ---
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final response = await api
          .getAdminUsers(_filter == 'all' ? null : _filter)
          .timeout(const Duration(seconds: 15));
      if (response.success && response.data != null) {
        final list = response.data!['users'] as List<dynamic>?;
        _users = list?.map((j) => User.fromJson(j as Map<String, dynamic>)).toList() ?? [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // --- On API failure ---
      if (!_useLocalOnly) {
        _errorMessage = response.message.isNotEmpty ? response.message : 'Cannot reach server';
      }

      // --- Mock path ---
      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 300));
        _users = _createMockUsers();
      } else {
        _errorMessage ??= 'Admin not authenticated';
      }
    } catch (e) {
      if (_useLocalOnly) {
        _users = _createMockUsers();
      } else {
        _errorMessage = 'Failed to load users. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<User> _createMockUsers() {
    final now = DateTime.now();
    return [
      User(
        id: '1', username: 'john_doe', email: 'john@example.com',
        firstName: 'John', lastName: 'Doe',
        role: UserRole.user, status: UserStatus.active,
        isBanned: false, isFlagged: false,
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      User(
        id: '2', username: 'jane_smith', email: 'jane@example.com',
        firstName: 'Jane', lastName: 'Smith',
        role: UserRole.user, status: UserStatus.active,
        isBanned: false, isFlagged: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      User(
        id: '3', username: 'bob_wilson', email: 'bob@example.com',
        firstName: 'Bob', lastName: 'Wilson',
        role: UserRole.user, status: UserStatus.active,
        isBanned: true, isFlagged: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      User(
        id: '4', username: 'alice_brown', email: 'alice@example.com',
        firstName: 'Alice', lastName: 'Brown',
        role: UserRole.user, status: UserStatus.active,
        isBanned: false, isFlagged: false,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      User(
        id: '5', username: 'charlie_dev', email: 'charlie@example.com',
        firstName: 'Charlie', lastName: 'Dev',
        role: UserRole.user, status: UserStatus.active,
        isBanned: false, isFlagged: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ].where((u) {
      if (_filter == 'flagged') return u.isFlagged;
      if (_filter == 'banned') return u.isBanned;
      return true;
    }).toList();
  }

  Future<void> flagUser(String userId) async {
    try {
      await _handleApiAction((api) => api.flagUser(userId), userId,
          (u) => u.copyWith(isFlagged: true));
    } catch (e) {
      _showToast('Failed to flag user', Colors.red);
    }
    notifyListeners();
  }

  Future<void> unflagUser(String userId) async {
    try {
      await _handleApiAction((api) => api.unflagUser(userId), userId,
          (u) => u.copyWith(isFlagged: false));
    } catch (e) {
      _showToast('Failed to unflag user', Colors.red);
    }
    notifyListeners();
  }

  Future<void> banUser(String userId) async {
    try {
      await _handleApiAction((api) => api.banUser(userId), userId,
          (u) => u.copyWith(isBanned: true, isFlagged: true));
    } catch (e) {
      _showToast('Failed to ban user', Colors.red);
    }
    notifyListeners();
  }

  Future<void> unbanUser(String userId) async {
    try {
      await _handleApiAction((api) => api.unbanUser(userId), userId,
          (u) => u.copyWith(isBanned: false));
    } catch (e) {
      _showToast('Failed to unban user', Colors.red);
    }
    notifyListeners();
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.resetPassword(userId, newPassword).timeout(const Duration(seconds: 15));
      _showToast(res.success ? 'Password reset successful — user will be logged out' : res.message,
          res.success ? Colors.green : Colors.red);
    } catch (e) {
      _showToast('Failed to reset password', Colors.red);
    }
    notifyListeners();
  }

  Future<void> _handleApiAction(
    Future<ApiResponse> Function(ApiService) action,
    String userId,
    User Function(User) transform,
  ) async {
    final token = await AuthService.getToken();
    final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
    final res = await action(api).timeout(const Duration(seconds: 15));
    if (res.success) {
      _applyUserTransform(userId, transform);
      _showToast('Success', Colors.green);
    } else {
      _showToast(res.message.isNotEmpty ? res.message : 'Request failed', Colors.red);
    }
  }

  void _applyUserTransform(String userId, User Function(User) transform) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final transformed = transform(_users[idx]);
      _updateUserLocally(userId, isFlagged: transformed.isFlagged, isBanned: transformed.isBanned);
    }
  }

  void _updateUserLocally(String userId, {bool? isFlagged, bool? isBanned}) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      _users[idx] = _users[idx].copyWith(
        isFlagged: isFlagged,
        isBanned: isBanned,
      );
    }
  }

  void _showToast(String msg, Color bg) {
    Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: bg, textColor: Colors.white);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

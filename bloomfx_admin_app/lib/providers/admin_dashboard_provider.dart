import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../models/admin_models.dart';
import '../services/admin_notification_service.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final ApiService _apiService;
  AdminDashboardStats _stats = AdminDashboardStats();
  bool _isLoading = false;
  String? _errorMessage;
  int _lastPendingDeposits = -1;
  int _lastPendingWithdrawals = -1;

  AdminDashboardProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  AdminDashboardStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get _useLocalOnly =>
      _apiService.baseUrl.contains('your-backend-api.com') ||
      _apiService.baseUrl.contains('10.0.2.2') ||
      _apiService.baseUrl.contains('127.0.0.1') ||
      _apiService.baseUrl.contains('localhost');

  Future<void> loadStats() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.getAdminDashboard().timeout(const Duration(seconds: 15));
      if (res.success && res.data != null) {
        _stats = AdminDashboardStats.fromJson(res.data);
        _checkPendingNotifications();
      } else if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 300));
        _stats = AdminDashboardStats(
          totalUsers: 5,
          totalDepositAmount: 84535.0,
          totalWithdrawalAmount: 12150.0,
          pendingDeposits: 2,
          pendingWithdrawals: 1,
          flaggedUsers: 2,
          bannedUsers: 1,
        );
        _checkPendingNotifications();
      } else {
        _errorMessage = res.message.isNotEmpty ? res.message : 'Cannot reach server';
      }
    } on TimeoutException catch (_) {
      _errorMessage = 'The server is taking too long to respond. Pull down to retry.';
    } catch (e) {
      if (_useLocalOnly) {
        _stats = AdminDashboardStats(
          totalUsers: 5,
          totalDepositAmount: 84535.0,
          totalWithdrawalAmount: 12150.0,
          pendingDeposits: 2,
          pendingWithdrawals: 1,
          flaggedUsers: 2,
          bannedUsers: 1,
        );
      } else {
        _errorMessage = 'Could not load stats. Pull down to retry.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkPendingNotifications() {
    if (_lastPendingDeposits >= 0 && _stats.pendingDeposits > _lastPendingDeposits) {
      AdminNotificationService.instance.showPendingDepositNotification(_stats.pendingDeposits);
    }
    if (_lastPendingWithdrawals >= 0 && _stats.pendingWithdrawals > _lastPendingWithdrawals) {
      AdminNotificationService.instance.showPendingWithdrawalNotification(_stats.pendingWithdrawals);
    }
    _lastPendingDeposits = _stats.pendingDeposits;
    _lastPendingWithdrawals = _stats.pendingWithdrawals;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

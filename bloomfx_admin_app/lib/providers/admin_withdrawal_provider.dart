import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../models/admin_models.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminWithdrawalProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<AdminWithdrawal> _withdrawals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'all';

  AdminWithdrawalProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  List<AdminWithdrawal> get withdrawals => _withdrawals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;

  bool get _useLocalOnly => _apiService.baseUrl.contains('your-backend-api.com') || _apiService.baseUrl.contains('10.0.2.2') || _apiService.baseUrl.contains('127.0.0.1') || _apiService.baseUrl.contains('localhost');

  void setStatusFilter(String f) {
    _statusFilter = f;
    loadWithdrawals();
  }

  Future<void> loadWithdrawals() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.getAdminWithdrawals(_statusFilter == 'all' ? null : _statusFilter);
      if (res.success && res.data != null) {
        final list = res.data!['withdrawals'] as List<dynamic>?;
        _withdrawals = list?.map((w) => AdminWithdrawal.fromJson(w as Map<String, dynamic>)).toList() ?? [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 300));
        _withdrawals = _createMockWithdrawals();
      }
    } catch (e) {
      if (_useLocalOnly) {
        _withdrawals = _createMockWithdrawals();
      } else {
        _errorMessage = 'Cannot reach server';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AdminWithdrawal> _createMockWithdrawals() {
    final now = DateTime.now();
    return [
      AdminWithdrawal(
        id: 'wd1', userId: '1', userName: 'John Doe', userEmail: 'john@example.com',
        amount: 200.0, network: 'BEP20', walletAddress: '0x1234...5678',
        status: 'pending', createdAt: now.subtract(const Duration(hours: 5)),
        isFlagged: false, isBanned: false,
      ),
      AdminWithdrawal(
        id: 'wd2', userId: '2', userName: 'Jane Smith', userEmail: 'jane@example.com',
        amount: 800.0, network: 'ERC20', walletAddress: '0xabcd...ef01',
        status: 'pending', createdAt: now.subtract(const Duration(hours: 12)),
        isFlagged: true, isBanned: false,
      ),
      AdminWithdrawal(
        id: 'wd3', userId: '4', userName: 'Alice Brown', userEmail: 'alice@example.com',
        amount: 350.0, network: 'Solana', walletAddress: 'Gs...7k',
        status: 'approved', createdAt: now.subtract(const Duration(days: 1)),
        processedAt: now.subtract(const Duration(hours: 6)),
        isFlagged: false, isBanned: false,
      ),
      AdminWithdrawal(
        id: 'wd4', userId: '1', userName: 'John Doe', userEmail: 'john@example.com',
        amount: 100.0, network: 'BEP20', walletAddress: '0x1234...5678',
        status: 'rejected', createdAt: now.subtract(const Duration(days: 3)),
        processedAt: now.subtract(const Duration(days: 2)),
        isFlagged: false, isBanned: false,
      ),
    ].where((w) => _statusFilter == 'all' || w.status == _statusFilter).toList();
  }

  Future<bool> approveWithdrawal(String withdrawalId) async {
    try {
      final idx = _withdrawals.indexWhere((w) => w.id == withdrawalId);
      if (idx < 0) {
        _showToast('Withdrawal not found', Colors.orange);
        return false;
      }
      final wd = _withdrawals[idx];
      if (wd.isFlagged || wd.isBanned) {
        _showToast('Cannot approve - user is flagged or banned', Colors.orange);
        return false;
      }

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.approveWithdrawal(withdrawalId);
      if (res.success) {
        _updateWithdrawalLocally(withdrawalId, 'approved');
        _showToast('Withdrawal approved', Colors.green);
        notifyListeners();
        return true;
      }
      _showToast(res.message, Colors.red);
      return false;
    } catch (e) {
      _showToast('Failed to approve withdrawal', Colors.red);
      return false;
    }
  }

  Future<bool> rejectWithdrawal(String withdrawalId) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.rejectWithdrawal(withdrawalId);
      if (res.success) {
        _updateWithdrawalLocally(withdrawalId, 'rejected');
        _showToast('Withdrawal rejected - balance refunded', Colors.orange);
        notifyListeners();
        return true;
      }
      _showToast(res.message, Colors.red);
      return false;
    } catch (e) {
      _showToast('Failed to reject withdrawal', Colors.red);
      return false;
    }
  }

  void _updateWithdrawalLocally(String id, String status) {
    final idx = _withdrawals.indexWhere((w) => w.id == id);
    if (idx != -1) {
      _withdrawals[idx] = _withdrawals[idx].copyWith(
        status: status,
        processedAt: status != 'pending' ? DateTime.now() : null,
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

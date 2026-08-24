import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../models/admin_models.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminDepositProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<AdminDeposit> _deposits = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'all';

  AdminDepositProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  List<AdminDeposit> get deposits => _deposits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;

  bool get _useLocalOnly => _apiService.baseUrl.contains('your-backend-api.com') || _apiService.baseUrl.contains('10.0.2.2') || _apiService.baseUrl.contains('127.0.0.1') || _apiService.baseUrl.contains('localhost');

  void setStatusFilter(String f) {
    _statusFilter = f;
    loadDeposits();
  }

  Future<void> loadDeposits() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.getAdminDeposits(_statusFilter == 'all' ? null : _statusFilter);
      if (res.success && res.data != null) {
        final list = res.data!['deposits'] as List<dynamic>?;
        _deposits = list?.map((d) => AdminDeposit.fromJson(d as Map<String, dynamic>)).toList() ?? [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 300));
        _deposits = _createMockDeposits();
      }
      else { _errorMessage = res.message.isNotEmpty ? res.message : 'Cannot reach server'; }
    } catch (e) {
      if (_useLocalOnly) {
        _deposits = _createMockDeposits();
      } else {
        _errorMessage = 'Failed to load deposits. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AdminDeposit> _createMockDeposits() {
    final now = DateTime.now();
    return [
      AdminDeposit(
        id: 'dep1', userId: '1', userName: 'John Doe', userEmail: 'john@example.com',
        amount: 500.0, network: 'BEP20', walletAddress: '0x1234...5678',
        status: 'pending', createdAt: now.subtract(const Duration(hours: 3)),
        expiresAt: now.add(const Duration(days: 27)), isFlagged: false, isBanned: false,
      ),
      AdminDeposit(
        id: 'dep2', userId: '2', userName: 'Jane Smith', userEmail: 'jane@example.com',
        amount: 1200.0, network: 'ERC20', walletAddress: '0xabcd...ef01',
        status: 'pending', createdAt: now.subtract(const Duration(hours: 8)),
        expiresAt: now.add(const Duration(days: 26)), isFlagged: true, isBanned: false,
      ),
      AdminDeposit(
        id: 'dep3', userId: '3', userName: 'Bob Wilson', userEmail: 'bob@example.com',
        amount: 250.0, network: 'Solana', walletAddress: 'Gs...7k',
        status: 'approved', createdAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.add(const Duration(days: 28)), isFlagged: true, isBanned: true,
      ),
      AdminDeposit(
        id: 'dep4', userId: '4', userName: 'Alice Brown', userEmail: 'alice@example.com',
        amount: 800.0, network: 'BEP20', walletAddress: '0x9876...5432',
        status: 'rejected', createdAt: now.subtract(const Duration(days: 5)),
        isFlagged: false, isBanned: false,
      ),
    ].where((d) => _statusFilter == 'all' || d.status == _statusFilter).toList();
  }

  Future<bool> approveDeposit(String depositId) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.approveDeposit(depositId);
      if (res.success) {
        _updateDepositLocally(depositId, 'approved');
        _showToast('Deposit approved', Colors.green);
        notifyListeners();
        return true;
      }
      _showToast(res.message, Colors.red);
      return false;
    } catch (e) {
      _showToast('Failed to approve deposit', Colors.red);
      return false;
    }
  }

  Future<bool> rejectDeposit(String depositId) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.rejectDeposit(depositId);
      if (res.success) {
        _updateDepositLocally(depositId, 'rejected');
        _showToast('Deposit rejected', Colors.orange);
        notifyListeners();
        return true;
      }
      _showToast(res.message, Colors.red);
      return false;
    } catch (e) {
      _showToast('Failed to reject deposit', Colors.red);
      return false;
    }
  }

  void _updateDepositLocally(String id, String status) {
    final idx = _deposits.indexWhere((d) => d.id == id);
    if (idx != -1) {
      _deposits[idx] = _deposits[idx].copyWith(status: status);
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

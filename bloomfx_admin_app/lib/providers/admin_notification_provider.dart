import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminNotificationProvider extends ChangeNotifier {
  final ApiService _apiService;
  bool _isLoading = false;
  String? _errorMessage;

  AdminNotificationProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get _useLocalOnly => _apiService.baseUrl.contains('your-backend-api.com') || _apiService.baseUrl.contains('10.0.2.2') || _apiService.baseUrl.contains('127.0.0.1') || _apiService.baseUrl.contains('localhost');

  Future<bool> sendNotification({
    required String title,
    required String message,
    required String sendType,
    List<String>? targetUsers,
    String type = 'info',
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final token = await AuthService.getToken();
      if (token == null) {
        _errorMessage = 'Admin not authenticated';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.sendAdminNotification({
        'title': title, 'message': message,
        'sendType': sendType, 'targetUsers': targetUsers, 'type': type,
      }).timeout(const Duration(seconds: 30));
      _isLoading = false;
      notifyListeners();
      if (res.success) {
        final msg = res.data?['message']?.toString() ?? 'Notification sent';
        _showToast(msg, Colors.green);
        return true;
      } else {
        _showToast(res.message, Colors.red);
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to send notification: $e';
      _showToast('Failed to send notification', Colors.red);
      notifyListeners();
      return false;
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

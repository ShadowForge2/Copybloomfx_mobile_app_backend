import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiResponse {
  final bool success;
  final Map<String, dynamic>? data;
  final String message;

  ApiResponse({required this.success, this.data, this.message = ''});
}

class ApiService {
  final String baseUrl;
  final String? authToken;

  ApiService({required this.baseUrl, this.authToken});

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $authToken';
    }
    return h;
  }

  String _friendlyError(dynamic e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (e is HttpException) {
      return 'Unable to reach the server. Please try again later.';
    }
    if (e is http.ClientException) {
      if (e.message.contains('timed out') || e.message.contains('timeout')) {
        return 'Request timed out. Please check your connection and try again.';
      }
      return 'Unable to connect to the server. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<ApiResponse> _get(String path) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
      return _parseResponse(res);
    } catch (e) {
      return ApiResponse(success: false, message: _friendlyError(e));
    }
  }

  Future<ApiResponse> _post(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _parseResponse(res);
    } catch (e) {
      return ApiResponse(success: false, message: _friendlyError(e));
    }
  }

  Future<ApiResponse> _put(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _parseResponse(res);
    } catch (e) {
      return ApiResponse(success: false, message: _friendlyError(e));
    }
  }

  Future<ApiResponse> _patch(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _parseResponse(res);
    } catch (e) {
      return ApiResponse(success: false, message: _friendlyError(e));
    }
  }

  ApiResponse _parseResponse(http.Response res) {
    Map<String, dynamic>? data;
    String message = '';
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
          message = decoded['error']?.toString() ?? decoded['message']?.toString() ?? '';
        }
      } catch (_) {}
    }
    final success = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse(success: success, data: data, message: message);
  }

  // ----- Auth -----
  Future<ApiResponse> login(String username, String password) =>
      _post('/api/auth/login', body: {'username': username, 'password': password});

  Future<ApiResponse> register(String username, String password, {String? email}) =>
      _post('/api/auth/signup', body: {'username': username, 'password': password, 'email': email});

  Future<ApiResponse> refreshToken(String token) =>
      _post('/api/auth/refresh', body: {'token': token});

  // ----- User -----
  Future<ApiResponse> getUserDashboard() => _get('/api/user/dashboard');
  Future<ApiResponse> getUserFinance() => _get('/api/user/finance');
  Future<ApiResponse> getUserNotifications() => _get('/api/user/notifications');
  Future<ApiResponse> getDepositStatus(String id) => _get('/api/user/deposits/$id/status');
  Future<ApiResponse> postUserDeposit({required double amount, required String network}) =>
      _post('/api/user/deposits', body: {'amount': amount, 'network': network});
  Future<ApiResponse> postUserWithdrawal({required double amount, required String network, required String walletAddress}) =>
      _post('/api/user/withdrawals', body: {'amount': amount, 'network': network, 'walletAddress': walletAddress});
  Future<ApiResponse> postUserDailyReward() => _post('/api/user/daily-reward');
  Future<ApiResponse> postUserCopyTradeSimulate() => _post('/api/user/copy-trades/simulate');
  Future<ApiResponse> postPaystackInitialize({required double amount}) =>
      _post('/api/user/paystack/initialize', body: {'amount': amount});
  Future<ApiResponse> postPaystackVerify(String reference) =>
      _post('/api/user/paystack/verify', body: {'reference': reference});
  Future<ApiResponse> redeemPromo(String code) =>
      _post('/api/user/promo/redeem', body: {'code': code});
  Future<ApiResponse> markNotificationsRead() => _post('/api/user/notifications/mark-read');
  Future<ApiResponse> updateProfile(Map<String, dynamic> data) =>
      _put('/api/user/profile', body: data);

  // ----- Admin -----
  Future<ApiResponse> getAdminDashboard() => _get('/api/admin/dashboard');
  Future<ApiResponse> getAdminDeposits(String? status) => _get('/api/admin/deposits${status != null && status != 'all' ? '?status=$status' : ''}');
  Future<ApiResponse> getAdminWithdrawals(String? status) => _get('/api/admin/withdrawals${status != null && status != 'all' ? '?status=$status' : ''}');
  Future<ApiResponse> getAdminPromos() => _get('/api/admin/promos');
  Future<ApiResponse> getAdminUsers(String? filter) => _get('/api/admin/users${filter != null && filter != 'all' ? '?filter=$filter' : ''}');
  Future<ApiResponse> approveDeposit(String id) => _post('/api/admin/deposits/$id/approve');
  Future<ApiResponse> rejectDeposit(String id) => _post('/api/admin/deposits/$id/reject');
  Future<ApiResponse> approveWithdrawal(String id) => _post('/api/admin/withdrawals/$id/approve');
  Future<ApiResponse> rejectWithdrawal(String id) => _post('/api/admin/withdrawals/$id/reject');
  Future<ApiResponse> createPromo(Map<String, dynamic> data) => _post('/api/admin/promos', body: data);
  Future<ApiResponse> togglePromo(String id) => _patch('/api/admin/promos/$id');
  Future<ApiResponse> flagUser(String id) => _post('/api/admin/users/$id/flag');
  Future<ApiResponse> unflagUser(String id) => _post('/api/admin/users/$id/unflag');
  Future<ApiResponse> banUser(String id) => _post('/api/admin/users/$id/ban');
  Future<ApiResponse> unbanUser(String id) => _post('/api/admin/users/$id/unban');
  Future<ApiResponse> resetPassword(String id, String password) =>
      _post('/api/auth/admin/reset-password', body: {'userId': id, 'newPassword': password});
  Future<ApiResponse> sendAdminNotification(Map<String, dynamic> data) =>
      _post('/api/admin/send-notification', body: data);
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/support.dart';
import 'auth_service.dart';

class SupportService {
  final String baseUrl;

  SupportService({required this.baseUrl});

  Future<Map<String, String>?> _authHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<SupportConversation?> getOrCreateConversation(String userId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return null;

      final url = '$baseUrl/api/support/conversation/$userId';
      if (kDebugMode) debugPrint('[SupportService] GET $url');

      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['conversation'] != null) {
          return SupportConversation.fromJson(
            body['conversation'] as Map<String, dynamic>,
          );
        }
      }
      if (kDebugMode) {
        debugPrint('[SupportService] getOrCreateConversation status=${res.statusCode} body=${res.body}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] getOrCreateConversation error: $e');
      return null;
    }
  }

  Future<List<SupportMessage>> getMessages(String conversationId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return [];

      final url = '$baseUrl/api/support/conversations/$conversationId/messages';
      if (kDebugMode) debugPrint('[SupportService] GET $url');

      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['messages'] as List? ?? [];
        return list
            .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] getMessages error: $e');
      return [];
    }
  }

  Future<SupportMessage?> sendMessage({
    required String conversationId,
    required String senderId,
    required String message,
  }) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return null;

      final url = '$baseUrl/api/support/conversations/$conversationId/messages';
      if (kDebugMode) debugPrint('[SupportService] POST $url');

      final res = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['message'] != null) {
          return SupportMessage.fromJson(
            body['message'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] sendMessage error: $e');
      return null;
    }
  }

  Future<bool> markMessageAsRead(String messageId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return false;

      final url = '$baseUrl/api/support/messages/$messageId/read';
      if (kDebugMode) debugPrint('[SupportService] PATCH $url');

      final res = await http
          .patch(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] markMessageAsRead error: $e');
      return false;
    }
  }

  Future<bool> closeConversation(String conversationId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return false;

      final url = '$baseUrl/api/support/conversations/$conversationId/close';
      if (kDebugMode) debugPrint('[SupportService] PATCH $url');

      final res = await http
          .patch(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] closeConversation error: $e');
      return false;
    }
  }

  Future<List<SupportConversation>> getAllConversations() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return [];

      final url = '$baseUrl/api/support/conversations';
      if (kDebugMode) debugPrint('[SupportService] GET $url');

      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['conversations'] as List? ?? [];
        return list
            .map((c) => SupportConversation.fromJson(c as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] getAllConversations error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String conversationId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return 0;

      final url = '$baseUrl/api/support/conversations/$conversationId/unread';
      if (kDebugMode) debugPrint('[SupportService] GET $url');

      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupportService] getUnreadCount error: $e');
      return 0;
    }
  }
}

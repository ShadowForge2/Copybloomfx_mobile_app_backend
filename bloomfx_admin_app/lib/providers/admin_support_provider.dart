import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminSupportProvider extends ChangeNotifier {
  final SupportService _supportService;

  List<SupportConversation> _conversations = [];
  Map<String, List<SupportMessage>> _messageCache =
      {}; // conversation_id -> messages
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedConversationId;
  bool _isSending = false;
  Timer? _pollTimer;

  AdminSupportProvider({required String baseUrl})
    : _supportService = SupportService(baseUrl: baseUrl);

  // Getters
  List<SupportConversation> get conversations => _conversations;
  List<SupportMessage> get currentMessages => _selectedConversationId != null
      ? (_messageCache[_selectedConversationId] ?? [])
      : [];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedConversationId => _selectedConversationId;
  bool get isSending => _isSending;

  SupportConversation? get selectedConversation {
    for (final c in _conversations) {
      if (c.id == _selectedConversationId) return c;
    }
    return null;
  }

  int get totalUnreadCount {
    int count = 0;
    for (final messages in _messageCache.values) {
      count += messages
          .where((m) => !m.isRead && m.senderType == MessageSenderType.user)
          .length;
    }
    return count;
  }

  /// Load all support conversations
  Future<void> loadConversations() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final all = await _supportService.getAllConversations();
      _conversations = all.where((c) => c.status != SupportConversationStatus.closed).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load conversations: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a conversation and load its messages
  Future<void> selectConversation(String conversationId) async {
    try {
      _selectedConversationId = conversationId;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Check cache first
      if (!_messageCache.containsKey(conversationId)) {
        final messages = await _supportService.getMessages(conversationId);
        _messageCache[conversationId] = messages;
      }

      // Mark unread user messages as read
      await markConversationAsRead(conversationId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load conversation: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a reply message as admin
  Future<bool> sendReply(String message, String adminUserId) async {
    final convId = _selectedConversationId;
    if (convId == null || message.isEmpty) return false;

    try {
      _isSending = true;
      _errorMessage = null;
      notifyListeners();

      final sentMessage = await _supportService.sendMessage(
        conversationId: convId,
        senderId: adminUserId,
        message: message,
      );

      if (sentMessage != null) {
        // Add to cache
        if (!_messageCache.containsKey(convId)) {
          _messageCache[convId] = [];
        }
        _messageCache[convId]!.add(sentMessage);

        // Update conversation status
        final convIdx = _conversations.indexWhere(
          (c) => c.id == convId,
        );
        if (convIdx >= 0) {
          final conv = _conversations[convIdx];
          _conversations[convIdx] = SupportConversation(
            id: conv.id,
            userId: conv.userId,
            status: SupportConversationStatus.waitingUser,
            lastMessageAt: DateTime.now(),
            createdAt: conv.createdAt,
            updatedAt: DateTime.now(),
          );
        }

        _isSending = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Failed to send message';
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error sending message: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    if (_messageCache.containsKey(conversationId)) {
      final messages = _messageCache[conversationId]!;
      for (final msg in messages.where(
        (m) => !m.isRead && m.senderType == MessageSenderType.user,
      )) {
        await _supportService.markMessageAsRead(msg.id);
      }
      // Update cache
      _messageCache[conversationId] = messages
          .map(
            (m) => m.isRead || m.senderType == MessageSenderType.admin
                ? m
                : SupportMessage(
                    id: m.id,
                    conversationId: m.conversationId,
                    senderType: m.senderType,
                    senderId: m.senderId,
                    message: m.message,
                    isRead: true,
                    createdAt: m.createdAt,
                  ),
          )
          .toList();
      notifyListeners();
    }
  }

  /// Close a conversation
  Future<bool> closeConversation(String conversationId) async {
    try {
      final success = await _supportService.closeConversation(conversationId);
      if (success) {
        final idx = _conversations.indexWhere((c) => c.id == conversationId);
        if (idx >= 0) {
          final conv = _conversations[idx];
          _conversations[idx] = SupportConversation(
            id: conv.id,
            userId: conv.userId,
            status: SupportConversationStatus.closed,
            lastMessageAt: conv.lastMessageAt,
            createdAt: conv.createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }

        if (_selectedConversationId == conversationId) {
          _selectedConversationId = null;
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error closing conversation: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add message from realtime subscription
  void addRealtimeMessage(String conversationId, SupportMessage message) {
    // Prevent duplicate messages
    if (!_messageCache.containsKey(conversationId)) {
      _messageCache[conversationId] = [];
    }

    if (!_messageCache[conversationId]!.any((m) => m.id == message.id)) {
      _messageCache[conversationId]!.add(message);
      notifyListeners();
    }
  }

  /// Update conversation in list
  void updateConversationStatus(
    String conversationId,
    SupportConversationStatus status,
  ) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      final conv = _conversations[idx];
      _conversations[idx] = SupportConversation(
        id: conv.id,
        userId: conv.userId,
        status: status,
        lastMessageAt: conv.lastMessageAt,
        createdAt: conv.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Deselect conversation
  void deselectConversation() {
    _selectedConversationId = null;
    notifyListeners();
  }

  /// Get unread count for a specific conversation (public accessor)
  int getUnreadCountForConversation(String conversationId) {
    if (!_messageCache.containsKey(conversationId)) return 0;
    return _messageCache[conversationId]!
        .where((m) => !m.isRead && m.senderType == MessageSenderType.user)
        .length;
  }

  /// Start polling for new messages (called from screen initState)
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_selectedConversationId != null) {
        _pollMessages(_selectedConversationId!);
      }
      _pollConversations();
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollMessages(String conversationId) async {
    try {
      final messages = await _supportService.getMessages(conversationId);
      if (messages.isNotEmpty) {
        _messageCache[conversationId] = messages;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _pollConversations() async {
    try {
      final convs = await _supportService.getAllConversations();
      _conversations = convs.where((c) => c.status != SupportConversationStatus.closed).toList();
      if (convs.isNotEmpty) {
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

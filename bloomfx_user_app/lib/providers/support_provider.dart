import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class SupportProvider extends ChangeNotifier {
  final SupportService _supportService;
  final String _baseUrl;
  final SupabaseRealtimeService _realtimeService = SupabaseRealtimeService();

  SupportConversation? _currentConversation;
  List<SupportMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSending = false;
  String? _messageSubscriptionId;
  String? _conversationSubscriptionId;
  Timer? _pollTimer;

  SupportProvider({required String baseUrl})
    : _baseUrl = baseUrl,
      _supportService = SupportService(baseUrl: baseUrl);

  // Getters
  SupportConversation? get currentConversation => _currentConversation;
  List<SupportMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSending => _isSending;
  bool get hasUnreadMessages => _messages.any(
    (msg) => !msg.isRead && msg.senderType == MessageSenderType.admin,
  );

  /// Start a new support conversation (closes current if any, forces new)
  Future<void> startNewConversation(String userId, String currentUserId) async {
    // Close existing open conversation first
    if (_currentConversation != null) {
      await _supportService.closeConversation(_currentConversation!.id);
      _cleanupRealtimeListeners();
    }
    _currentConversation = null;
    _messages.clear();
    notifyListeners();
    await initializeChat(userId, currentUserId);
  }

  /// Initialize support chat - get or create conversation
  Future<void> initializeChat(String userId, String currentUserId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentConversation = await _supportService.getOrCreateConversation(
        userId,
      );

      if (_currentConversation != null) {
        await loadMessages();
        _setupRealtimeListeners();
      }
      // null conversation = no open conversation yet; UI shows welcome state

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not start the chat. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load messages from current conversation
  Future<void> loadMessages() async {
    if (_currentConversation == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final loadedMessages = await _supportService.getMessages(
        _currentConversation!.id,
      );
      _messages = loadedMessages;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load messages. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a message — auto-creates conversation if none exists
  Future<bool> sendMessage(String message, String senderId) async {
    if (message.isEmpty) return false;

    // Auto-create conversation if needed
    if (_currentConversation == null) {
      await initializeChat(senderId, senderId);
      // One retry if first attempt failed
      if (_currentConversation == null) {
        await initializeChat(senderId, senderId);
      }
      if (_currentConversation == null) {
        _errorMessage = 'Failed to create support conversation. Check your connection and try again.';
        notifyListeners();
        return false;
      }
    }

    try {
      _isSending = true;
      _errorMessage = null;
      notifyListeners();

      final sentMessage = await _supportService.sendMessage(
        conversationId: _currentConversation!.id,
        senderId: senderId,
        message: message,
      );

      if (sentMessage != null) {
        _messages.add(sentMessage);
        _isSending = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Failed to send message. The server may be down.';
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send message. Please try again.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      final success = await _supportService.markMessageAsRead(messageId);
      if (success) {
        // Update local message
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          final msg = _messages[index];
          _messages[index] = SupportMessage(
            id: msg.id,
            conversationId: msg.conversationId,
            senderType: msg.senderType,
            senderId: msg.senderId,
            message: msg.message,
            isRead: true,
            createdAt: msg.createdAt,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking message as read: $e');
      }
    }
  }

  /// Close the conversation
  Future<bool> closeConversation() async {
    if (_currentConversation == null) return false;

    try {
      final success = await _supportService.closeConversation(
        _currentConversation!.id,
      );
      if (success) {
        _currentConversation = null;
        _messages.clear();
        _cleanupRealtimeListeners();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to close conversation. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Setup realtime listeners for this conversation
  void _setupRealtimeListeners() {
    if (_currentConversation == null) return;

    _messageSubscriptionId = _realtimeService.subscribeToMessages(
      _currentConversation!.id,
      (message) => addRealtimeMessage(message),
    );

    _conversationSubscriptionId = _realtimeService
        .subscribeToConversationUpdates(
          _currentConversation!.id,
          (conversation) => updateConversationStatus(conversation.status),
        );

    if (kDebugMode) {
      debugPrint(
        '[SupportProvider] Setup realtime listeners for conversation ${_currentConversation!.id}',
      );
    }
  }

  /// Clean up realtime listeners
  void _cleanupRealtimeListeners() {
    if (_messageSubscriptionId != null) {
      _realtimeService.unsubscribeFromMessages(_messageSubscriptionId!);
    }
    if (_conversationSubscriptionId != null) {
      _realtimeService.unsubscribeFromConversationUpdates(
        _conversationSubscriptionId!,
      );
    }
    if (kDebugMode) {
      debugPrint('[SupportProvider] Cleaned up realtime listeners');
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Add message from realtime subscription
  void addRealtimeMessage(SupportMessage message) {
    // Prevent duplicate messages
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
      notifyListeners();
    }
  }

  /// Handle realtime conversation update
  void updateConversationStatus(SupportConversationStatus status) {
    if (_currentConversation != null) {
      _currentConversation = SupportConversation(
        id: _currentConversation!.id,
        userId: _currentConversation!.userId,
        status: status,
        lastMessageAt: _currentConversation!.lastMessageAt,
        createdAt: _currentConversation!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Start polling for new messages (called from screen initState)
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollMessages();
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollMessages() async {
    if (_currentConversation == null) return;
    try {
      final messages = await _supportService.getMessages(
        _currentConversation!.id,
      );
      if (messages.isNotEmpty && messages.length != _messages.length) {
        _messages = messages;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    _cleanupRealtimeListeners();
    super.dispose();
  }
}

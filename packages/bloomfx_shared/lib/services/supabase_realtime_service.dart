import 'package:flutter/foundation.dart';
import '../models/support.dart';

typedef OnMessageCallback = void Function(SupportMessage message);
typedef OnConversationUpdateCallback =
    void Function(SupportConversation conversation);

class SupabaseRealtimeService {
  // This is a stub for the realtime service
  // In production, this would connect to Supabase Realtime using supabase package
  // For now, it provides the interface that apps can use

  static final SupabaseRealtimeService _instance =
      SupabaseRealtimeService._internal();

  factory SupabaseRealtimeService() {
    return _instance;
  }

  SupabaseRealtimeService._internal();

  final Map<String, OnMessageCallback> _messageListeners = {};
  final Map<String, OnConversationUpdateCallback> _conversationListeners = {};

  /// Subscribe to new messages in a conversation
  /// Returns a subscription ID that can be used to unsubscribe
  String subscribeToMessages(
    String conversationId,
    OnMessageCallback onMessage,
  ) {
    final subscriptionId =
        'msg_${conversationId}_${DateTime.now().millisecondsSinceEpoch}';

    _messageListeners[subscriptionId] = onMessage;

    if (kDebugMode) {
      debugPrint(
        '[SupabaseRealtime] subscribed to messages in conversation: $conversationId',
      );
    }

    // In production, this would set up a Supabase realtime listener on support_messages table
    // WHERE conversation_id = $conversationId
    // LISTEN ON INSERT, UPDATE

    return subscriptionId;
  }

  /// Subscribe to conversation updates
  String subscribeToConversationUpdates(
    String conversationId,
    OnConversationUpdateCallback onUpdate,
  ) {
    final subscriptionId =
        'conv_${conversationId}_${DateTime.now().millisecondsSinceEpoch}';

    _conversationListeners[subscriptionId] = onUpdate;

    if (kDebugMode) {
      debugPrint(
        '[SupabaseRealtime] subscribed to conversation updates: $conversationId',
      );
    }

    // In production, this would set up a Supabase realtime listener on support_conversations table
    // WHERE id = $conversationId
    // LISTEN ON UPDATE

    return subscriptionId;
  }

  /// Unsubscribe from messages
  void unsubscribeFromMessages(String subscriptionId) {
    _messageListeners.remove(subscriptionId);
    if (kDebugMode) {
      debugPrint(
        '[SupabaseRealtime] unsubscribed from messages: $subscriptionId',
      );
    }
  }

  /// Unsubscribe from conversation updates
  void unsubscribeFromConversationUpdates(String subscriptionId) {
    _conversationListeners.remove(subscriptionId);
    if (kDebugMode) {
      debugPrint(
        '[SupabaseRealtime] unsubscribed from conversation updates: $subscriptionId',
      );
    }
  }

  /// Subscribe to all conversations for admin
  String subscribeToAllConversations(OnConversationUpdateCallback onUpdate) {
    final subscriptionId = 'all_conv_${DateTime.now().millisecondsSinceEpoch}';

    _conversationListeners[subscriptionId] = onUpdate;

    if (kDebugMode) {
      debugPrint('[SupabaseRealtime] subscribed to all conversations (admin)');
    }

    // In production, this would set up a Supabase realtime listener on support_conversations table
    // for all conversations (admin has access to all)

    return subscriptionId;
  }

  /// Emit a message event (for testing/demo)
  void _emitMessage(String conversationId, SupportMessage message) {
    final listenersToCall = _messageListeners.entries
        .where((e) => e.key.contains(conversationId))
        .map((e) => e.value)
        .toList();

    for (final listener in listenersToCall) {
      listener(message);
    }
  }

  /// Emit a conversation update event (for testing/demo)
  void _emitConversationUpdate(SupportConversation conversation) {
    for (final listener in _conversationListeners.values) {
      listener(conversation);
    }
  }

  /// Clean up all subscriptions
  void dispose() {
    _messageListeners.clear();
    _conversationListeners.clear();
    if (kDebugMode) {
      debugPrint('[SupabaseRealtime] disposed all subscriptions');
    }
  }
}

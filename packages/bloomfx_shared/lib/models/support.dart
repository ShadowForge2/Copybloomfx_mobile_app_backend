enum SupportConversationStatus {
  open,
  closed,
  waitingUser,
  waitingAdmin;

  static SupportConversationStatus fromString(String value) {
    final normalized = value.replaceAll('_', '').toLowerCase();
    return SupportConversationStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => open,
    );
  }

  String toDisplayString() {
    switch (this) {
      case open:
        return 'Open';
      case closed:
        return 'Closed';
      case waitingUser:
        return 'Waiting for User';
      case waitingAdmin:
        return 'Waiting for Admin';
    }
  }
}

class SupportConversation {
  final String id;
  final String userId;
  final SupportConversationStatus status;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportConversation({
    required this.id,
    required this.userId,
    required this.status,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: SupportConversationStatus.fromString(
        (json['status'] as String?) ?? 'open',
      ),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status.name
          .replaceAll(
            RegExp('[A-Z]'),
            '_${RegExp('[A-Z]').firstMatch(status.name)!.group(0)!.toLowerCase()}',
          )
          .toLowerCase()
          .replaceFirst('_', ''),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum MessageSenderType { user, admin }

class SupportMessage {
  final String id;
  final String conversationId;
  final MessageSenderType senderType;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderType: (json['sender_type'] as String).toLowerCase() == 'admin'
          ? MessageSenderType.admin
          : MessageSenderType.user,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] is bool
          ? (json['is_read'] as bool)
          : (json['is_read'] as num?)?.toInt() == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_type': senderType == MessageSenderType.admin ? 'admin' : 'user',
      'sender_id': senderId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum NotificationType {
  info,
  warning,
  success,
  urgent,
  maintenance;

  String get label {
    switch (this) {
      case NotificationType.info:
        return 'Information';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.success:
        return 'Success';
      case NotificationType.urgent:
        return 'Urgent';
      case NotificationType.maintenance:
        return 'Maintenance';
    }
  }

  static NotificationType fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'warning':
        return NotificationType.warning;
      case 'success':
        return NotificationType.success;
      case 'urgent':
        return NotificationType.urgent;
      case 'maintenance':
        return NotificationType.maintenance;
      default:
        return NotificationType.info;
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      type: NotificationType.fromString(json['notification_type']?.toString() ?? json['type']?.toString()),
      isRead: _parseBool(json['is_read'] ?? json['isRead']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == true || value == 1 || value == '1' || value == 'true') return true;
    if (value == false || value == 0 || value == '0' || value == 'false') return false;
    return false;
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

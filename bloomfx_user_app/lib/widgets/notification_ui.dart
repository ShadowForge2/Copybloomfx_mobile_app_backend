import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

class NotificationBell extends StatelessWidget {
  final VoidCallback onTap;

  const NotificationBell({super.key, required this.onTap});

  static String badgeLabel(int unread) => unread > 9 ? '9+' : '$unread';

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, child) {
        final unread = notifProvider.unreadCount;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Stack(
              children: [
                const Icon(Icons.notifications, color: Color(0xFF7D8590), size: 18),
                if (unread > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeLabel(unread),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showNotificationSheet(BuildContext context) {
  final notifProvider = context.read<NotificationProvider>();
  notifProvider.fetchNotifications();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Consumer<NotificationProvider>(
        builder: (context, notifProvider, _) {
          final notifications = notifProvider.notifications;
          final unread = notifProvider.unreadCount;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            NotificationBell.badgeLabel(unread),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (unread > 0)
                        GestureDetector(
                          onTap: () => notifProvider.markAllAsRead(),
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                if (notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: Color(0xFF7D8590), fontSize: 14),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF30363D), height: 1),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        return _buildNotificationItem(
                          n,
                          onTap: () {
                            if (!n.isRead) {
                              notifProvider.markOneAsRead(n.id);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildNotificationItem(AppNotification n, {VoidCallback? onTap}) {
  final color = _notificationColor(n.type);
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: n.isRead ? Colors.transparent : const Color(0x0DFFFFFF),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_notificationIcon(n.type), color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!n.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF58A6FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: const TextStyle(color: Color(0xFF7D8590), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  n.timeAgo,
                  style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _notificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.info:
      return Icons.info_outline;
    case NotificationType.warning:
      return Icons.warning_amber;
    case NotificationType.success:
      return Icons.check_circle_outline;
    case NotificationType.urgent:
      return Icons.error_outline;
    case NotificationType.maintenance:
      return Icons.construction;
  }
}

Color _notificationColor(NotificationType type) {
  switch (type) {
    case NotificationType.info:
      return const Color(0xFF58A6FF);
    case NotificationType.warning:
      return const Color(0xFFFFA726);
    case NotificationType.success:
      return const Color(0xFF4CAF50);
    case NotificationType.urgent:
      return const Color(0xFFEF5350);
    case NotificationType.maintenance:
      return const Color(0xFFAB47BC);
  }
}

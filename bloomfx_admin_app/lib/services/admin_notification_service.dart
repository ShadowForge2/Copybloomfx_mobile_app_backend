import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance = AdminNotificationService._();
  static AdminNotificationService get instance => _instance;

  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  AdminNotificationService._();

  Future<void> init() async {
    if (_initialized) return;

    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin!.initialize(initSettings);

    _initialized = true;
  }

  Future<void> showPendingDepositNotification(int count) async {
    if (!_initialized || _plugin == null) return;

    const androidDetails = AndroidNotificationDetails(
      'admin_pending_channel',
      'Pending Actions',
      channelDescription: 'Notifications for pending admin actions',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFFFFA726),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin!.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Pending Deposit${count > 1 ? "s" : ""}',
      '$count user deposit${count > 1 ? "s" : ""} awaiting approval.',
      details,
    );
  }

  Future<void> showPendingWithdrawalNotification(int count) async {
    if (!_initialized || _plugin == null) return;

    const androidDetails = AndroidNotificationDetails(
      'admin_pending_channel',
      'Pending Actions',
      channelDescription: 'Notifications for pending admin actions',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF42A5F5),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin!.show(
      DateTime.now().millisecondsSinceEpoch % 100000 + 1,
      'Pending Withdrawal${count > 1 ? "s" : ""}',
      '$count user withdrawal${count > 1 ? "s" : ""} awaiting processing.',
      details,
    );
  }
}

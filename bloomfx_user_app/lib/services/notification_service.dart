import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'news_generator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  late FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService._();

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

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!kIsWeb) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
    }
    return true;
  }

  Future<void> showNewsNotification(NewsItem item) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'trading_news_channel',
      'Trading News',
      channelDescription: 'Automated trading market news and updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF58A6FF),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await NewsStorage.append(item);

    await _plugin.show(
      item.id.hashCode,
      'Market News',
      item.message,
      details,
      payload: item.id,
    );
  }

  Future<void> showNewsNotificationFromBackground(String message) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'trading_news_channel',
      'Trading News',
      channelDescription: 'Automated trading market news and updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF58A6FF),
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    final item = NewsItem(
      id: 'news_os_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      createdAt: DateTime.now(),
    );
    await NewsStorage.append(item);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Market News',
      message,
      details,
    );
  }

  Future<void> showDepositPending(double amount) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Deposit and withdrawal status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFFFF9800),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Deposit Pending',
      'Your \$${amount.toStringAsFixed(2)} deposit is awaiting admin approval.',
      details,
    );
  }

  Future<void> showDepositApproved(double amount) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Deposit and withdrawal status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF4CAF50),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Deposit Approved',
      'Your deposit of \$${amount.toStringAsFixed(2)} has been approved and credited to your tradable balance.',
      details,
    );
  }

  Future<void> showWithdrawalDelivered(double amount) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Deposit and withdrawal status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF4CAF50),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Withdrawal Delivered',
      'Your withdrawal of \$${amount.toStringAsFixed(2)} has been delivered to your wallet.',
      details,
    );
  }

  Future<void> showSupportReply(String message) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'support_channel',
      'Support',
      channelDescription: 'Support ticket replies',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF58A6FF),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Support Reply',
      message,
      details,
    );
  }
}

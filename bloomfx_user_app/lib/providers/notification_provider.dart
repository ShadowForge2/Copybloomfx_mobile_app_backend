import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _apiService;
  List<AppNotification> _notifications = [];
  String? _errorMessage;
  Timer? _pollTimer;
  bool _isBackgrounded = false;
  Duration _pollInterval = const Duration(seconds: 30);

  NotificationProvider(this._apiService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isBackgrounded = true;
      stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      if (_pollTimer == null) {
        startPolling(interval: _pollInterval);
      }
    }
  }

  List<AppNotification> get notifications => _notifications;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get _useLocalOnly => _apiService.baseUrl.contains('your-backend-api.com') || _apiService.baseUrl.contains('10.0.2.2') || _apiService.baseUrl.contains('127.0.0.1');

  List<AppNotification> _buildLocalNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: '1',
        title: 'Welcome to BloomFX',
        message: 'Your account is active. Start by making a deposit to unlock copy trading features.',
        type: NotificationType.info,
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: '2',
        title: 'Deposit Approved',
        message: 'Your deposit of \$250.00 has been approved and credited to your locked balance.',
        type: NotificationType.success,
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: '3',
        title: 'Rank Up!',
        message: 'Congratulations! You\'ve advanced to Stock Shark rank. New copy trade limits unlocked.',
        type: NotificationType.success,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: '4',
        title: 'System Maintenance',
        message: 'Scheduled maintenance on Sunday 2:00 AM UTC. Services may be unavailable for 2 hours.',
        type: NotificationType.maintenance,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AppNotification(
        id: '5',
        title: 'Copy Trade Completed',
        message: 'BTC/USDT buy simulation completed with \$15.50 profit. Added to withdrawable balance.',
        type: NotificationType.success,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  Future<void> fetchNotifications() async {
    _errorMessage = null;
    try {
      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 300));
        _notifications = _buildLocalNotifications();
      } else {
        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final res = api.getUserNotifications();
        final response = await res;
        if (response.success && response.data != null) {
          final rawList = response.data!['notifications'] as List<dynamic>? ?? [];
          _notifications = rawList
              .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n as Map)))
              .toList();
          _sortNotifications();
        } else {
          _errorMessage = response.message.isNotEmpty ? response.message : 'Notifications unavailable';
          if (_notifications.isEmpty) {
            _notifications = _buildLocalNotifications();
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load notifications. Please try again.';
      if (_notifications.isEmpty) {
        _notifications = _buildLocalNotifications();
      }
    }
    notifyListeners();
  }

  Future<int> markAllAsRead() async {
    try {
      var count = 0;
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
          count++;
        }
      }
      if (count > 0) {
        if (!_useLocalOnly) {
          final token = await AuthService.getToken();
          final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
          await api.markNotificationsRead();
        }
        notifyListeners();
      }
      return count;
    } catch (e) {
      _errorMessage = 'Failed to mark notifications as read. Please try again.';
      notifyListeners();
      return 0;
    }
  }

  void markOneAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id && !n.isRead);
    if (idx < 0) return;
    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();
  }

  void _sortNotifications() {
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollInterval = interval;
    _pollTimer?.cancel();
    fetchNotifications();
    _pollTimer = Timer.periodic(interval, (_) => fetchNotifications());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    super.dispose();
  }
}

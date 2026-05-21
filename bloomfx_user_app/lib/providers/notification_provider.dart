import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../models/notification_model.dart';
import '../services/news_sync.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _apiService;
  List<AppNotification> _notifications = [];
  String? _errorMessage;
  Timer? _pollTimer;
  bool _isBackgrounded = false;
  Duration _pollInterval = const Duration(seconds: 30);
  final Set<String> _seenIds = {};
  bool _isFirstFetch = true;

  Future<void> _loadSeenNotificationIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('seen_notification_ids_$userId');
      if (list != null) {
        _seenIds.addAll(list);
      }
    } catch (_) {}
  }

  Future<void> _saveSeenNotificationIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen_notification_ids_$userId', _seenIds.toList());
    } catch (_) {}
  }

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

  bool get _useLocalOnly =>
      _apiService.baseUrl.contains('your-backend-api.com') ||
      _apiService.baseUrl.contains('10.0.2.2') ||
      _apiService.baseUrl.contains('127.0.0.1') ||
      _apiService.baseUrl.contains('localhost');

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
        message: 'Your deposit of \$250.00 has been approved and credited to your tradable balance.',
        type: NotificationType.success,
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
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
        final user = await AuthService.getCurrentUser();
        final uId = user?.id;
        if (uId != null) {
          await _loadSeenNotificationIds(uId);
        }

        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final response = await api.getUserNotifications();
        if (response.success && response.data != null) {
          final rawList = response.data!['notifications'] as List<dynamic>? ?? [];
          _notifications = rawList
              .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n as Map)))
              .toList();
          _sortNotifications();
          await _handleIncomingNotifications(_notifications, triggerLocalNotifications: !_isFirstFetch);
          _isFirstFetch = false;
          if (uId != null) {
            await _saveSeenNotificationIds(uId);
          }
        } else if (_notifications.isEmpty) {
          _errorMessage =
              response.message.isNotEmpty ? response.message : 'Notifications unavailable';
        }
      }
    } catch (e) {
      if (_notifications.isEmpty) {
        _errorMessage = 'Failed to load notifications. Please try again.';
      }
    }
    notifyListeners();
  }

  Future<void> _handleIncomingNotifications(List<AppNotification> list, {bool triggerLocalNotifications = true}) async {
    await NewsSync.mirrorNotificationsToNews(list);

    for (final n in list) {
      final added = _seenIds.add(n.id);
      if (!added) continue;
      if (_isBackgrounded) continue;
      if (!triggerLocalNotifications) continue;
      final title = n.title.toLowerCase();
      final amount = _parseAmount(n.message);
      if (title.contains('deposit approved')) {
        await NotificationService.instance.showDepositApproved(amount);
      } else if (title.contains('withdrawal delivered')) {
        await NotificationService.instance.showWithdrawalDelivered(amount);
      } else if (title.contains('deposit pending')) {
        await NotificationService.instance.showDepositPending(amount);
      } else if (title.contains('support reply')) {
        await NotificationService.instance.showSupportReply(n.message);
      }
    }
  }

  double _parseAmount(String message) {
    final match = RegExp(r'\$([0-9]+(?:\.[0-9]+)?)').firstMatch(message);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  Future<int> markAllAsRead() async {
    try {
      if (!_useLocalOnly) {
        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final res = await api.markNotificationsRead();
        if (!res.success) {
          _errorMessage = res.message.isNotEmpty
              ? res.message
              : 'Failed to mark notifications as read. Please try again.';
          notifyListeners();
          return 0;
        }
      }

      var count = 0;
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
          count++;
        }
      }
      if (count > 0) notifyListeners();
      return count;
    } catch (e) {
      _errorMessage = 'Failed to mark notifications as read. Please try again.';
      notifyListeners();
      return 0;
    }
  }

  Future<void> markOneAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id && !n.isRead);
    if (idx < 0) return;

    if (!_useLocalOnly) {
      try {
        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final res = await api.markNotificationsRead(notificationId: id);
        if (!res.success) {
          _errorMessage = res.message.isNotEmpty
              ? res.message
              : 'Failed to mark notification as read.';
          notifyListeners();
          return;
        }
      } catch (e) {
        _errorMessage = 'Failed to mark notification as read.';
        notifyListeners();
        return;
      }
    }

    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();
  }

  void _sortNotifications() {
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void startPolling({Duration interval = const Duration(seconds: 15)}) {
    _pollInterval = interval;
    _pollTimer?.cancel();
    _seenIds.clear();
    _isFirstFetch = true;
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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'news_generator.dart';
import 'notification_service.dart';

const String _backgroundTaskName = 'com.bloomfx.news_generation';
const String _lastNewsTimeKey = 'last_news_notification_time';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _handleBackgroundTask();
      return true;
    } catch (e) {
      debugPrint('Background task error: $e');
      return false;
    }
  });
}

Future<void> _handleBackgroundTask() async {
  final prefs = await SharedPreferences.getInstance();
  final lastTime = prefs.getInt(_lastNewsTimeKey) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  final elapsedHours = (now - lastTime) / 3600000;

  if (elapsedHours >= 2) {
    await NotificationService.instance.init();
    final message = NewsGenerator.generate();
    final newsItem = NewsItem(
      id: 'news_bg_$now',
      message: message,
      createdAt: DateTime.now(),
    );
    final existing = await NewsStorage.load();
    existing.insert(0, newsItem);
    await NewsStorage.save(existing);
    await NotificationService.instance.showNewsNotificationFromBackground(message);
    await prefs.setInt(_lastNewsTimeKey, now);
  }
}

class BackgroundService {
  static Future<void> register() async {
    if (kIsWeb) return;

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      _backgroundTaskName,
      _backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

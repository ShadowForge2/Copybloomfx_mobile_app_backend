import '../models/notification_model.dart';
import 'news_generator.dart';

/// Keeps News tab in sync with platform broadcasts and persisted local news alerts.
class NewsSync {
  NewsSync._();

  static Future<void> mirrorNotificationsToNews(List<AppNotification> notifications) async {
    for (final n in notifications) {
      await NewsStorage.appendPlatformMessage(
        id: n.id,
        title: n.title,
        message: n.message,
        createdAt: n.createdAt,
      );
    }
  }

  static Future<void> fromLocalNewsAlert(NewsItem item) async {
    await NewsStorage.append(item);
  }
}

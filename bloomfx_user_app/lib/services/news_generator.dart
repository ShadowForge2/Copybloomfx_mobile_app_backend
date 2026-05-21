import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class NewsGenerator {
  NewsGenerator._();

  static final Random _random = Random();

  static const List<String> _markets = [
    'EUR/USD', 'GBP/USD', 'USD/JPY', 'BTC/USD', 'ETH/USD',
    'XAU/USD', 'NASDAQ', 'US30', 'AUD/USD', 'USD/CAD',
  ];

  static const List<String> _volatility = [
    'low volatility', 'moderate volatility', 'high volatility',
    'extreme volatility', 'unstable volatility',
  ];

  static const List<String> _signals = [
    'breakout setup', 'trend continuation', 'reversal pattern',
    'momentum trade', 'swing opportunity', 'AI trade signal',
    'copy trading opportunity',
  ];

  static const List<String> _actions = [
    'maintain stop-loss protection', 'reduce leverage exposure',
    'monitor active positions', 'secure partial profits',
    'trade cautiously', 'follow strict risk management',
    'avoid emotional trading',
  ];

  static const List<String> _sentiments = [
    'bullish momentum detected', 'bearish pressure increasing',
    'market uncertainty remains high', 'institutional activity detected',
    'trading volume rising rapidly', 'strong support zone identified',
    'resistance levels remain active',
  ];

  static const List<String> _templates = [
    '{market} currently shows {volatility}. {signal} identified with projected 2:1 reward potential. Traders should {action}.',
    'AI trading engine detected {signal} on {market}. Current conditions indicate {volatility}. Recommended to {action}.',
    '{market} market update: {sentiment}. Analysts report {volatility} conditions while {signal} remains active.',
    'Copy trading alert: {signal} activated on {market}. Market conditions reflect {volatility}. Users should {action}.',
    'Trading news update: {market} continues showing {volatility}. AI systems identified {signal}. Traders advised to {action}.',
    'Volatility warning for {market}. Current session reflects {volatility} as {sentiment}. Recommended to {action}.',
    'Market intelligence detected {signal} on {market}. Current sentiment indicates {sentiment}. Maintain disciplined trading behavior.',
    '{market} experiences increased activity during {volatility} session. AI trading systems identified potential 2:1 setups.',
    'Risk management notification: {market} conditions remain unstable. {signal} detected while {sentiment}. Traders should {action}.',
    'Automated trading update: {market} currently shows {volatility}. AI systems continue monitoring {signal} opportunities.',
  ];

  static String _pick(List<String> list) => list[_random.nextInt(list.length)];

  static String generate() {
    final template = _pick(_templates);
    return template
        .replaceAll('{market}', _pick(_markets))
        .replaceAll('{volatility}', _pick(_volatility))
        .replaceAll('{signal}', _pick(_signals))
        .replaceAll('{action}', _pick(_actions))
        .replaceAll('{sentiment}', _pick(_sentiments));
  }

  static List<String> generateBatch(int count) {
    return List.generate(count, (_) => generate());
  }

  static int nextIntervalHours() {
    return 2 + _random.nextInt(4);
  }
}

class NewsItem {
  final String id;
  final String message;
  final DateTime createdAt;
  final String category;

  NewsItem({
    required this.id,
    required this.message,
    required this.createdAt,
    this.category = 'Market Update',
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'category': category,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: json['id'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        category: json['category'] as String? ?? 'Market Update',
      );
}

class NewsStorage {
  NewsStorage._();

  static const _key = 'cached_news_items';
  static const _viewedKey = 'news_last_viewed_at';
  static const _maxItems = 100;

  static Future<List<NewsItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<NewsItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = items.take(_maxItems).toList();
    await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  static Future<int> unreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastViewed = prefs.getInt(_viewedKey) ?? 0;
    final items = await load();
    return items.where((item) => item.createdAt.millisecondsSinceEpoch > lastViewed).length;
  }

  static Future<void> markViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_viewedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Append a single item (deduped by id) — used for OS news alerts and platform messages.
  static Future<void> append(NewsItem item) async {
    final existing = await load();
    if (existing.any((e) => e.id == item.id)) return;
    existing.insert(0, item);
    await save(existing);
  }

  /// Mirror admin/platform inbox messages onto the News tab (not deposit/withdrawal alerts).
  static bool shouldMirrorInboxToNews(String title) {
    final t = title.toLowerCase();
    const inboxOnly = [
      'deposit pending',
      'deposit approved',
      'deposit rejected',
      'withdrawal submitted',
      'withdrawal delivered',
      'withdrawal rejected',
      'account created',
    ];
    return !inboxOnly.any(t.contains);
  }

  static Future<void> appendPlatformMessage({
    required String id,
    required String title,
    required String message,
    required DateTime createdAt,
    String category = 'Platform Update',
  }) async {
    if (!shouldMirrorInboxToNews(title)) return;
    final body = title.trim().isEmpty ? message : '$title\n\n$message';
    await append(NewsItem(
      id: 'news_$id',
      message: body,
      createdAt: createdAt,
      category: category,
    ));
  }
}

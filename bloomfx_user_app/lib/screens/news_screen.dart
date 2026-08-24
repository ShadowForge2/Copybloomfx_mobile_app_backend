import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../providers/auth_provider.dart';
import '../services/news_generator.dart';
import '../services/notification_service.dart';
import '../widgets/notification_ui.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with WidgetsBindingObserver {
  final List<NewsItem> _news = [];
  Timer? _generationTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPersistedNews();
    _scheduleNext();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _reloadFromStorage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generationTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadFromStorage();
    }
  }

  Future<void> _reloadFromStorage() async {
    final stored = await NewsStorage.load();
    if (!mounted) return;
    setState(() => _news
      ..clear()
      ..addAll(stored));
    await NewsStorage.markViewed();
  }

  Future<void> _loadPersistedNews() async {
    final stored = await NewsStorage.load();
    if (!mounted) return;
    if (stored.isNotEmpty) {
      setState(() => _news.addAll(stored));
    } else {
      final now = DateTime.now();
      final messages = NewsGenerator.generateBatch(15);
      final batch = <NewsItem>[];
      for (int i = 0; i < messages.length; i++) {
        batch.add(NewsItem(
          id: 'news_${now.millisecondsSinceEpoch}_$i',
          message: messages[i],
          createdAt: now.subtract(Duration(minutes: (messages.length - i) * 17)),
        ));
      }
      batch.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _news.addAll(batch));
      NewsStorage.save(batch);
    }
  }

  void _scheduleNext() {
    _generationTimer?.cancel();
    final hours = NewsGenerator.nextIntervalHours();
    final ms = hours * 3600000;
    _generationTimer = Timer(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      final item = NewsItem(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        message: NewsGenerator.generate(),
        createdAt: DateTime.now(),
      );
      setState(() {
        _news.insert(0, item);
        if (_news.length > 100) _news.removeLast();
      });
      await NewsStorage.save(_news);
      NotificationService.instance.showNewsNotification(item);
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.user == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        final user = authProvider.user!;
        return SafeArea(
          child: Column(
            children: [
              _buildHeader(user),
              Expanded(
                child: _news.isEmpty
                    ? const Center(child: Text('No news yet', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _news.length,
                        itemBuilder: (_, i) => _NewsCard(item: _news[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.newspaper, color: Color(0xFFD4AF37), size: 24),
          const SizedBox(width: 12),
          const Text('Market News', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(onTap: () => showNotificationSheet(context)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF7D8590), size: 20),
                const SizedBox(width: 8),
                Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_icon, size: 18, color: _iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(item.timeAgo, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.category, style: TextStyle(color: _iconColor, fontSize: 9)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    final msg = item.message.toLowerCase();
    if (msg.contains('volatility') || msg.contains('warning') || msg.contains('risk')) return Icons.warning_amber;
    if (msg.contains('ai ') || msg.contains('automated') || msg.contains('engine')) return Icons.auto_awesome;
    if (msg.contains('copy trade') || msg.contains('copy trading')) return Icons.content_copy;
    if (msg.contains('btc') || msg.contains('eth') || msg.contains('crypto')) return Icons.currency_bitcoin;
    if (msg.contains('gold') || msg.contains('xau')) return Icons.toll;
    if (msg.contains('profit') || msg.contains('bullish') || msg.contains('opportunity')) return Icons.trending_up;
    if (msg.contains('bearish') || msg.contains('decline') || msg.contains('pressure')) return Icons.trending_down;
    return Icons.newspaper;
  }

  Color get _iconColor {
    final msg = item.message.toLowerCase();
    if (msg.contains('volatility') || msg.contains('warning') || msg.contains('extreme')) return Colors.orange;
    if (msg.contains('risk') || msg.contains('bearish') || msg.contains('decline') || msg.contains('unstable')) return Colors.red;
    if (msg.contains('bullish') || msg.contains('profit') || msg.contains('opportunity') || msg.contains('support')) return Colors.green;
    if (msg.contains('ai ') || msg.contains('automated') || msg.contains('intelligence')) return const Color(0xFFD4AF37);
    return const Color(0xFF7D8590);
  }
}
